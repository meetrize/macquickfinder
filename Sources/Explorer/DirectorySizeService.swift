import Foundation
import FileList

enum DirectorySizeSchedulePriority: Int, Comparable, Sendable {
    case visible = 0
    case normal = 1
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 后台计算文件夹大小，带优先级队列、内存缓存与 generation 取消。
actor DirectorySizeService {
    static let shared = DirectorySizeService()
    
    private struct CacheEntry {
        let result: DirectorySizeComputeResult
        let directoryMTime: Date?
    }
    
    private struct WorkItem: Sendable {
        let path: String
        let showHiddenFiles: Bool
        let priority: DirectorySizeSchedulePriority
        let generation: UInt
    }
    
    private var cache: [String: CacheEntry] = [:]
    private var activeGeneration: UInt = 0
    private var queue: [WorkItem] = []
    private var runningTasks: [String: Task<Void, Never>] = [:]
    private var runningCount = 0
    private let maxConcurrent = 2
    private let maxCacheEntries = 300
    
    private init() {}
    
    func resetSession(generation: UInt) {
        activeGeneration = generation
        queue.removeAll()
        for task in runningTasks.values {
            task.cancel()
        }
        runningTasks.removeAll()
        runningCount = 0
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
        priority: DirectorySizeSchedulePriority = .normal
    ) {
        guard DirectorySizePreferences.autoCalculateDirectorySizes else { return }
        
        let generation = activeGeneration
        for path in paths {
            guard DirectorySizeVolumeFilter.shouldAutoCalculate(path: path) else { continue }
            enqueue(
                WorkItem(
                    path: path,
                    showHiddenFiles: showHiddenFiles,
                    priority: priority,
                    generation: generation
                )
            )
        }
        processQueue()
    }
    
    private func enqueue(_ item: WorkItem) {
        guard item.generation == activeGeneration else { return }
        
        let key = Self.cacheKey(path: item.path, showHiddenFiles: item.showHiddenFiles)
        
        if let entry = cache[key], Self.isCacheValid(entry: entry, path: item.path) {
            Task { @MainActor in
                DirectorySizeOverlay.shared.apply(
                    path: item.path,
                    result: entry.result,
                    generation: item.generation
                )
            }
            return
        }
        
        if runningTasks[key] != nil {
            return
        }
        
        if let index = queue.firstIndex(where: {
            Self.cacheKey(path: $0.path, showHiddenFiles: $0.showHiddenFiles) == key
        }) {
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
        while runningCount < maxConcurrent, let nextIndex = queue.firstIndex(where: { $0.generation == activeGeneration }) {
            let item = queue.remove(at: nextIndex)
            startWork(item)
        }
    }
    
    private func startWork(_ item: WorkItem) {
        let key = Self.cacheKey(path: item.path, showHiddenFiles: item.showHiddenFiles)
        guard runningTasks[key] == nil else { return }
        
        runningCount += 1
        let task = Task.detached(priority: .utility) {
            defer {
                Task { await DirectorySizeService.shared.finishWork(cacheKey: key) }
            }
            
            let result: DirectorySizeComputeResult
            do {
                result = try await Self.computeDirectorySize(
                    at: URL(fileURLWithPath: item.path),
                    showHiddenFiles: item.showHiddenFiles
                )
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            
            let stillActive = await DirectorySizeService.shared.storeResultIfActive(
                cacheKey: key,
                path: item.path,
                result: result,
                generation: item.generation
            )
            guard stillActive else { return }
            
            await MainActor.run {
                DirectorySizeOverlay.shared.apply(
                    path: item.path,
                    result: result,
                    generation: item.generation
                )
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
        cache = cache.filter { key, _ in
            let cachedPath = Self.path(fromCacheKey: key)
            if cachedPath == path { return false }
            if cachedPath.hasPrefix(descendantPrefix) { return false }
            return true
        }
        
        for showHidden in [true, false] {
            let key = Self.cacheKey(path: path, showHiddenFiles: showHidden)
            runningTasks[key]?.cancel()
            runningTasks.removeValue(forKey: key)
            queue.removeAll {
                Self.cacheKey(path: $0.path, showHiddenFiles: $0.showHiddenFiles) == key
            }
        }
        
        Task { @MainActor in
            DirectorySizeOverlay.shared.remove(paths: [path])
        }
    }
    
    private func storeResultIfActive(
        cacheKey: String,
        path: String,
        result: DirectorySizeComputeResult,
        generation: UInt
    ) -> Bool {
        guard generation == activeGeneration else { return false }
        
        if cache.count >= maxCacheEntries {
            cache.removeAll(keepingCapacity: true)
        }
        cache[cacheKey] = CacheEntry(
            result: result,
            directoryMTime: Self.directoryMTime(path: path)
        )
        return true
    }
    
    private static func cacheKey(path: String, showHiddenFiles: Bool) -> String {
        "\(path)|\(showHiddenFiles)"
    }
    
    private static func path(fromCacheKey key: String) -> String {
        String(key.split(separator: "|", maxSplits: 1).first ?? Substring(key))
    }
    
    private static func directoryMTime(path: String) -> Date? {
        try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
    }
    
    private static func isCacheValid(entry: CacheEntry, path: String) -> Bool {
        guard let current = directoryMTime(path: path),
              let cached = entry.directoryMTime else { return false }
        return current == cached
    }
    
    private static func computeDirectorySize(
        at url: URL,
        showHiddenFiles: Bool
    ) async throws -> DirectorySizeComputeResult {
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
            let visible = showHiddenFiles
                ? contents
                : contents.filter { !$0.hasPrefix(".") }
            if visible.isEmpty { return .complete(0) }
        }
        
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !showHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [
                .totalFileAllocatedSizeKey,
                .fileSizeKey,
                .isRegularFileKey
            ],
            options: options
        ) else {
            return .complete(0)
        }
        
        let propertyKeys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .isRegularFileKey
        ]
        
        var total: Int64 = 0
        var fileCount = 0
        let startedAt = ContinuousClock.now
        
        while let fileURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            
            if DirectorySizeComputePolicy.shouldStopEnumerating(
                fileCount: fileCount,
                startedAt: startedAt,
                now: ContinuousClock.now
            ) {
                return .lowerBound(total)
            }
            
            guard let values = try? fileURL.resourceValues(forKeys: propertyKeys),
                  values.isRegularFile == true else { continue }
            
            let fileSize = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            total += fileSize
            
            fileCount += 1
            if fileCount % 800 == 0 {
                await Task.yield()
            }
        }
        
        return .complete(total)
    }
}
