import AppKit
import Foundation

/// 缩略图内存 LRU 缓存。
final class ThumbnailCache {
    struct Key: Hashable, Sendable {
        let path: String
        let modificationTimestamp: TimeInterval
        let fileSize: Int64
        let sizeBucket: Int
        
        init(row: FileListRow, sizeBucket: Int) {
            path = row.iconPath
            modificationTimestamp = row.modificationDate.timeIntervalSinceReferenceDate
            fileSize = row.size
            self.sizeBucket = sizeBucket
        }
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
    
    private let maxEntryCount = 500
    private let maxTotalCost = 150 * 1024 * 1024
    
    func entry(for key: Key) -> Entry? {
        if let entry = storage[key] {
            touch(key)
            return entry
        }
        if let diskEntry = diskCache.load(for: key) {
            storage[key] = diskEntry
            accessOrder.append(key)
            totalCost += diskEntry.cost
            evictIfNeeded()
            return diskEntry
        }
        return nil
    }
    
    func store(_ image: NSImage, isThumbnail: Bool, for key: Key) {
        let cost = estimatedCost(of: image)
        if let existing = storage[key] {
            totalCost -= existing.cost
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
        
        let entry = Entry(image: image, isThumbnail: isThumbnail, cost: cost)
        storage[key] = entry
        accessOrder.append(key)
        totalCost += cost
        evictIfNeeded()
        diskCache.store(image, isThumbnail: isThumbnail, for: key)
    }
    
    func removeAll() {
        storage.removeAll()
        accessOrder.removeAll()
        totalCost = 0
        diskCache.removeAll()
    }
    
    private func touch(_ key: Key) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    private func evictIfNeeded() {
        while (storage.count > maxEntryCount || totalCost > maxTotalCost), let oldest = accessOrder.first {
            accessOrder.removeFirst()
            if let removed = storage.removeValue(forKey: oldest) {
                totalCost -= removed.cost
            }
        }
    }
    
    private func estimatedCost(of image: NSImage) -> Int {
        let size = image.size
        let scale = image.recommendedLayerContentsScale(0)
        let pixels = Int(size.width * scale) * Int(size.height * scale)
        return max(pixels * 4, 16_384)
    }
}
