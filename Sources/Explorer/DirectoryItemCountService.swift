import Foundation
import FileList

enum DirectoryItemCountSchedulePriority: Int, Comparable, Sendable {
    case visible = 0
    case normal = 1
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 后台统计文件夹直接子项数量（非递归），供缩略图角标展示。
actor DirectoryItemCountService {
    static let shared = DirectoryItemCountService()
    
    private struct CacheEntry {
        let count: Int
        let directoryMTime: Date?
    }
    
    private struct WorkItem: Sendable {
        let path: String
        let showHiddenFiles: Bool
        let priority: DirectoryItemCountSchedulePriority
        let generation: UInt
    }
    
    private var cache: [String: CacheEntry] = [:]
    private var activeGeneration: UInt = 0
    private var queue: [WorkItem] = []
    private var runningTasks: [String: Task<Void, Never>] = [:]
    private var runningCount = 0
    private let maxConcurrent = 3
    private let maxCacheEntries = 500
    
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
        priority: DirectoryItemCountSchedulePriority = .normal
    ) {
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
                DirectoryItemCountOverlay.shared.apply(
                    path: item.path,
                    count: entry.count,
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
        while runningCount < maxConcurrent, !queue.isEmpty {
            let item = queue.removeFirst()
            let key = Self.cacheKey(path: item.path, showHiddenFiles: item.showHiddenFiles)
            guard runningTasks[key] == nil else { continue }
            
            runningCount += 1
            let task = Task {
                defer {
                    Task { await DirectoryItemCountService.shared.finishWork(cacheKey: key) }
                }
                
                let count = await Self.countImmediateChildren(
                    at: item.path,
                    showHiddenFiles: item.showHiddenFiles
                )
                
                let stillActive = await DirectoryItemCountService.shared.storeResultIfActive(
                    cacheKey: key,
                    path: item.path,
                    showHiddenFiles: item.showHiddenFiles,
                    count: count,
                    generation: item.generation
                )
                guard stillActive else { return }
                
                await MainActor.run {
                    DirectoryItemCountOverlay.shared.apply(
                        path: item.path,
                        count: count,
                        generation: item.generation
                    )
                }
            }
            runningTasks[key] = task
        }
    }
    
    private func finishWork(cacheKey: String) {
        runningTasks.removeValue(forKey: cacheKey)
        runningCount = max(0, runningCount - 1)
        processQueue()
    }
    
    private func invalidatePath(_ path: String) {
        for showHidden in [true, false] {
            let key = Self.cacheKey(path: path, showHiddenFiles: showHidden)
            cache.removeValue(forKey: key)
            runningTasks[key]?.cancel()
            runningTasks.removeValue(forKey: key)
            queue.removeAll {
                Self.cacheKey(path: $0.path, showHiddenFiles: $0.showHiddenFiles) == key
            }
        }
        Task { @MainActor in
            DirectoryItemCountOverlay.shared.remove(paths: [path])
        }
    }
    
    @discardableResult
    private func storeResultIfActive(
        cacheKey: String,
        path: String,
        showHiddenFiles: Bool,
        count: Int,
        generation: UInt
    ) -> Bool {
        guard generation == activeGeneration else { return false }
        let mtime = Self.directoryModificationDate(path: path)
        cache[cacheKey] = CacheEntry(count: count, directoryMTime: mtime)
        trimCacheIfNeeded()
        return true
    }
    
    private func trimCacheIfNeeded() {
        guard cache.count > maxCacheEntries else { return }
        let overflow = cache.count - maxCacheEntries
        for key in cache.keys.prefix(overflow) {
            cache.removeValue(forKey: key)
        }
    }
    
    private static func cacheKey(path: String, showHiddenFiles: Bool) -> String {
        "\(path)|\(showHiddenFiles)"
    }
    
    private static func isCacheValid(entry: CacheEntry, path: String) -> Bool {
        guard let currentMTime = directoryModificationDate(path: path) else {
            return entry.directoryMTime == nil
        }
        guard let cachedMTime = entry.directoryMTime else { return false }
        return abs(cachedMTime.timeIntervalSince(currentMTime)) < 0.001
    }
    
    private static func directoryModificationDate(path: String) -> Date? {
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
    
    private static func countImmediateChildren(
        at path: String,
        showHiddenFiles: Bool
    ) async -> Int {
        await Task.detached(priority: .utility) {
            let url = URL(fileURLWithPath: path)
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else {
                return 0
            }
            if showHiddenFiles {
                return names.count
            }
            var count = 0
            for name in names {
                let childURL = url.appendingPathComponent(name)
                let values = try? childURL.resourceValues(forKeys: [.isHiddenKey])
                if values?.isHidden != true {
                    count += 1
                }
            }
            return count
        }.value
    }
}
