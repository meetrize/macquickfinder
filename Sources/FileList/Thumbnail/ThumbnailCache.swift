import AppKit
import Foundation

/// 缩略图内存 LRU 缓存。
final class ThumbnailCache {
    struct Key: Hashable, Sendable {
        let path: String
        let modificationTimestamp: TimeInterval
        let fileSize: Int64
        let sizeBucket: Int
        /// 自定义缩略图渲染版本；变更后使旧 QL 磁盘缓存失效。
        let rendererRevision: Int

        init(row: FileListRow, sizeBucket: Int) {
            path = row.iconPath
            modificationTimestamp = row.modificationDate.timeIntervalSinceReferenceDate
            fileSize = row.size
            self.sizeBucket = sizeBucket
            rendererRevision = Self.rendererRevision(for: path)
        }

        init(
            path: String,
            modificationTimestamp: TimeInterval,
            fileSize: Int64,
            sizeBucket: Int,
            rendererRevision: Int = 0
        ) {
            self.path = path
            self.modificationTimestamp = modificationTimestamp
            self.fileSize = fileSize
            self.sizeBucket = sizeBucket
            self.rendererRevision = rendererRevision
        }

        private static func rendererRevision(for path: String) -> Int {
            let lower = path.lowercased()
            if lower.hasSuffix(".md") || lower.hasSuffix(".markdown") {
                return markdownThumbnailRendererRevision
            }
            return 0
        }

        /// Markdown 自定义缩略图版本；调整渲染逻辑时递增以使旧缓存失效。
        static let markdownThumbnailRendererRevision = 4
    }
    
    struct Entry {
        let image: NSImage
        let isThumbnail: Bool
        let cost: Int
    }
    
    private var storage: [Key: Entry] = [:]
    private var accessOrder: [Key] = []
    private var totalCost = 0
    private let diskCache = ThumbnailDiskCache()
    private let lock = NSLock()
    
    private let maxEntryCount = 500
    static let defaultMaxTotalCost = 80 * 1024 * 1024
    static let criticalMaxTotalCost = 32 * 1024 * 1024
    private var maxTotalCost = ThumbnailCache.defaultMaxTotalCost
    
    /// 仅查内存 LRU，主线程安全且不做磁盘 I/O。
    func memoryEntry(for key: Key) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[key] else { return nil }
        touchLocked(key)
        return entry
    }
    
    /// 先查内存，未命中则在后台读磁盘缓存。
    func loadEntry(for key: Key, completion: @escaping (Entry?) -> Void) {
        if let entry = memoryEntry(for: key) {
            completion(entry)
            return
        }
        
        diskCache.load(for: key) { [weak self] diskEntry in
            guard let self, let diskEntry else {
                completion(nil)
                return
            }
            self.lock.lock()
            self.storage[key] = diskEntry
            self.accessOrder.append(key)
            self.totalCost += diskEntry.cost
            self.evictIfNeededLocked()
            self.lock.unlock()
            completion(diskEntry)
        }
    }
    
    func store(_ image: NSImage, isThumbnail: Bool, for key: Key) {
        let cost = ThumbnailImageCost.estimatedBytes(of: image)
        lock.lock()
        if let existing = storage[key] {
            totalCost -= existing.cost
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
        
        let entry = Entry(image: image, isThumbnail: isThumbnail, cost: cost)
        storage[key] = entry
        accessOrder.append(key)
        totalCost += cost
        evictIfNeededLocked()
        lock.unlock()
        
        diskCache.store(image, isThumbnail: isThumbnail, for: key)
    }
    
    /// 仅清空内存 LRU；磁盘缓存保留，供切换目录后快速回填。
    func clearMemory() {
        lock.lock()
        storage.removeAll()
        accessOrder.removeAll()
        totalCost = 0
        lock.unlock()
    }

    /// 调整内存 LRU 预算并立即按新上限淘汰。
    func setMemoryBudget(_ bytes: Int) {
        lock.lock()
        maxTotalCost = max(1, bytes)
        evictIfNeededLocked()
        lock.unlock()
    }

    func restoreDefaultMemoryBudget() {
        setMemoryBudget(Self.defaultMaxTotalCost)
    }
    
    /// 清空内存与磁盘缓存（设置项「清除缩略图缓存」等场景使用）。
    func purgeAll() {
        clearMemory()
        diskCache.removeAll()
    }

    /// 将磁盘缓存裁剪到预算内，保留最近访问项。
    func trimDiskCache() {
        diskCache.trimToBudget()
    }
    
    private func touchLocked(_ key: Key) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    private func evictIfNeededLocked() {
        while (storage.count > maxEntryCount || totalCost > maxTotalCost), let oldest = accessOrder.first {
            accessOrder.removeFirst()
            if let removed = storage.removeValue(forKey: oldest) {
                totalCost -= removed.cost
            }
        }
    }
}
