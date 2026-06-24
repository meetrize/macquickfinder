import Foundation
import FileList

struct DirectoryMetadataWorkItem: Sendable {
    let path: String
    let showHiddenFiles: Bool
    let priority: DirectoryMetadataSchedulePriority
    let generation: UInt

    var cacheKey: String {
        DirectoryMetadataCache.key(path: path, showHiddenFiles: showHiddenFiles)
    }
}

enum DirectoryMetadataCache {
    static func key(path: String, showHiddenFiles: Bool) -> String {
        "\(path)|\(showHiddenFiles)"
    }

    static func path(fromCacheKey key: String) -> String {
        String(key.split(separator: "|", maxSplits: 1).first ?? Substring(key))
    }

    static func directoryMTime(path: String) -> Date? {
        try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
    }

    static func isExactMTimeValid(cached: Date?, path: String) -> Bool {
        guard let current = directoryMTime(path: path),
              let cached else { return false }
        return current == cached
    }

    static func isFuzzyMTimeValid(cached: Date?, path: String) -> Bool {
        guard let currentMTime = directoryMTime(path: path) else {
            return cached == nil
        }
        guard let cachedMTime = cached else { return false }
        return abs(cachedMTime.timeIntervalSince(currentMTime)) < 0.001
    }
}

struct DirectoryMetadataServiceConfiguration<Entry: Sendable> {
    let maxConcurrent: Int
    let maxCacheEntries: Int
    let clearsEntireCacheWhenFull: Bool
    let invalidateDescendants: Bool
    /// 路径切换 `resetSession` 后将缓存裁剪到此条数；`nil` 表示不裁剪。
    let sessionResetCacheRetention: Int?
    let scheduleEnabled: @Sendable () -> Bool
    let shouldSchedulePath: @Sendable (String) -> Bool
    let isCacheValid: @Sendable (Date?, String) -> Bool
    let compute: @Sendable (String, Bool) async throws -> Entry
    let apply: @MainActor @Sendable (String, Entry, UInt) -> Void
    let remove: @MainActor @Sendable ([String]) -> Void
}

/// 共享优先级队列、内存缓存、generation 取消与 invalidate 逻辑的泛型目录元数据 Actor。
actor DirectoryMetadataService<Entry: Sendable> {
    private struct CacheEntry {
        let value: Entry
        let directoryMTime: Date?
    }

    private let configuration: DirectoryMetadataServiceConfiguration<Entry>
    private var cache: [String: CacheEntry] = [:]
    private var activeGeneration: UInt = 0
    private var queue: [DirectoryMetadataWorkItem] = []
    private var runningTasks: [String: Task<Void, Never>] = [:]
    private var runningCount = 0

    init(configuration: DirectoryMetadataServiceConfiguration<Entry>) {
        self.configuration = configuration
    }

    func resetSession(generation: UInt) {
        activeGeneration = generation
        queue.removeAll()
        for task in runningTasks.values {
            task.cancel()
        }
        runningTasks.removeAll()
        runningCount = 0
        if let retention = configuration.sessionResetCacheRetention {
            trimCacheTo(maxEntries: retention)
        }
    }

    /// 内存压力等场景下裁剪 Actor 内缓存。
    func trimCache(retainingAtMost maxEntries: Int) {
        trimCacheTo(maxEntries: maxEntries)
    }

    func invalidate(paths: [String]) {
        guard !paths.isEmpty else { return }
        for path in paths {
            invalidatePath(path)
        }
        processQueue()
    }

    func schedule(
        paths: [String],
        showHiddenFiles: Bool,
        priority: DirectoryMetadataSchedulePriority = .normal
    ) {
        guard configuration.scheduleEnabled() else { return }

        let generation = activeGeneration
        for path in paths {
            guard configuration.shouldSchedulePath(path) else { continue }
            enqueue(
                DirectoryMetadataWorkItem(
                    path: path,
                    showHiddenFiles: showHiddenFiles,
                    priority: priority,
                    generation: generation
                )
            )
        }
        processQueue()
    }

    private func enqueue(_ item: DirectoryMetadataWorkItem) {
        guard item.generation == activeGeneration else { return }

        let key = item.cacheKey

        if let entry = cache[key],
           configuration.isCacheValid(entry.directoryMTime, item.path) {
            let value = entry.value
            Task { @MainActor in
                configuration.apply(item.path, value, item.generation)
            }
            return
        }

        if runningTasks[key] != nil {
            return
        }

        if let index = queue.firstIndex(where: { $0.cacheKey == key }) {
            if item.priority < queue[index].priority {
                queue[index] = item
                sortQueue()
            }
            return
        }

        queue.append(item)
        sortQueue()
    }

    private func sortQueue() {
        queue.sort {
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.path < $1.path
        }
    }

    private func processQueue() {
        while runningCount < configuration.maxConcurrent,
              let nextIndex = queue.firstIndex(where: { $0.generation == activeGeneration }) {
            let item = queue.remove(at: nextIndex)
            startWork(item)
        }
    }

    private func startWork(_ item: DirectoryMetadataWorkItem) {
        let key = item.cacheKey
        guard runningTasks[key] == nil else { return }

        runningCount += 1
        let configuration = configuration
        let service = self
        let task = Task.detached(priority: .utility) {
            defer {
                Task { await service.finishWork(cacheKey: key) }
            }

            let value: Entry
            do {
                value = try await configuration.compute(item.path, item.showHiddenFiles)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            let stillActive = await service.storeResultIfActive(
                cacheKey: key,
                path: item.path,
                value: value,
                generation: item.generation
            )
            guard stillActive else { return }

            await MainActor.run {
                configuration.apply(item.path, value, item.generation)
            }
        }
        runningTasks[key] = task
    }

    private func finishWork(cacheKey: String) {
        runningTasks.removeValue(forKey: cacheKey)
        runningCount = max(0, runningCount - 1)
        processQueue()
    }

    private func invalidatePath(_ path: String) {
        let descendantPrefix = path + "/"
        if configuration.invalidateDescendants {
            cache = cache.filter { key, _ in
                let cachedPath = DirectoryMetadataCache.path(fromCacheKey: key)
                if cachedPath == path { return false }
                if cachedPath.hasPrefix(descendantPrefix) { return false }
                return true
            }

            for key in runningTasks.keys {
                let cachedPath = DirectoryMetadataCache.path(fromCacheKey: key)
                guard cachedPath == path || cachedPath.hasPrefix(descendantPrefix) else { continue }
                runningTasks[key]?.cancel()
                runningTasks.removeValue(forKey: key)
            }

            queue.removeAll { item in
                item.path == path || item.path.hasPrefix(descendantPrefix)
            }
        }

        for showHidden in [true, false] {
            let key = DirectoryMetadataCache.key(path: path, showHiddenFiles: showHidden)
            if !configuration.invalidateDescendants {
                cache.removeValue(forKey: key)
            }
            runningTasks[key]?.cancel()
            runningTasks.removeValue(forKey: key)
            queue.removeAll { $0.cacheKey == key }
        }

        Task { @MainActor in
            configuration.remove([path])
        }
    }

    private func storeResultIfActive(
        cacheKey: String,
        path: String,
        value: Entry,
        generation: UInt
    ) -> Bool {
        guard generation == activeGeneration else { return false }

        if cache.count >= configuration.maxCacheEntries {
            if configuration.clearsEntireCacheWhenFull {
                cache.removeAll(keepingCapacity: true)
            } else {
                trimCacheIfNeeded()
            }
        }

        cache[cacheKey] = CacheEntry(
            value: value,
            directoryMTime: DirectoryMetadataCache.directoryMTime(path: path)
        )
        return true
    }

    private func trimCacheIfNeeded() {
        trimCacheTo(maxEntries: configuration.maxCacheEntries)
    }

    private func trimCacheTo(maxEntries: Int) {
        guard cache.count > maxEntries else { return }
        let overflow = cache.count - maxEntries
        for key in cache.keys.prefix(overflow) {
            cache.removeValue(forKey: key)
        }
    }
}

extension DirectoryMetadataService {
    struct TestingSnapshot: Sendable {
        let activeGeneration: UInt
        let cacheCount: Int
        let queuedItems: [(path: String, priority: DirectoryMetadataSchedulePriority, generation: UInt)]
        let runningKeys: [String]
    }

    func testingSnapshot() -> TestingSnapshot {
        TestingSnapshot(
            activeGeneration: activeGeneration,
            cacheCount: cache.count,
            queuedItems: queue.map { ($0.path, $0.priority, $0.generation) },
            runningKeys: Array(runningTasks.keys)
        )
    }
}
