import Foundation

/// 进程级悬停预览 LRU 缓存（字节预算 + 条目上限）。
@MainActor
final class HoverPreviewCache {
    static let shared = HoverPreviewCache()

    private struct Entry {
        let key: String
        var payload: HoverPreviewPayload
        var cost: Int
    }

    private var order: [String] = []
    private var storage: [String: Entry] = [:]
    private var totalCost = 0

    private init() {}

    static func makeKey(path: String, modificationDate: Date, size: Int64) -> String {
        "\(path)|\(modificationDate.timeIntervalSince1970)|\(size)"
    }

    func payload(for key: String) -> HoverPreviewPayload? {
        guard let entry = storage[key] else { return nil }
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
            order.append(key)
        }
        return entry.payload
    }

    func store(_ payload: HoverPreviewPayload, for key: String) {
        let cost = payload.approximateByteCost
        if let existing = storage[key] {
            totalCost -= existing.cost
            storage[key] = Entry(key: key, payload: payload, cost: cost)
            totalCost += cost
            if let index = order.firstIndex(of: key) {
                order.remove(at: index)
            }
            order.append(key)
        } else {
            storage[key] = Entry(key: key, payload: payload, cost: cost)
            order.append(key)
            totalCost += cost
        }
        trimIfNeeded()
    }

    func trimToHalf() {
        let target = HoverPreviewMetrics.cacheBudgetBytes / 2
        while totalCost > target || order.count > HoverPreviewMetrics.cacheMaxEntries / 2 {
            evictOldest()
        }
    }

    private func trimIfNeeded() {
        while totalCost > HoverPreviewMetrics.cacheBudgetBytes
            || order.count > HoverPreviewMetrics.cacheMaxEntries
        {
            evictOldest()
        }
    }

    private func evictOldest() {
        guard let oldest = order.first else { return }
        order.removeFirst()
        if let entry = storage.removeValue(forKey: oldest) {
            totalCost -= entry.cost
        }
    }

    #if DEBUG
    var debugEntryCount: Int { order.count }
    var debugTotalCost: Int { totalCost }
    #endif
}
