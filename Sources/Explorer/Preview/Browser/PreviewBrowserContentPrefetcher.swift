import Foundation

@MainActor
final class PreviewBrowserContentPrefetcher {
    private struct CacheEntry {
        let itemID: String
        let data: Data
    }

    private var entries: [CacheEntry] = []
    private var scheduledTask: Task<Void, Never>?

    func hasCached(for itemID: String) -> Bool {
        entries.contains { $0.itemID == itemID }
    }

    func schedulePrefetch(
        items: [FileItem],
        centerIndex: Int,
        settleDelayMilliseconds: UInt64 = PreviewBrowserStripMetrics.contentPrefetchSettleMilliseconds
    ) {
        guard items.indices.contains(centerIndex) else { return }
        guard !DirectorySizeVolumeFilter.isNetworkVolume(path: items[centerIndex].url.path) else {
            cancel()
            return
        }
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            if settleDelayMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: settleDelayMilliseconds * 1_000_000)
                guard !Task.isCancelled else { return }
            }
            await self?.prefetchAdjacent(items: items, centerIndex: centerIndex)
        }
    }

    func consume(for itemID: String) -> Data? {
        guard let index = entries.firstIndex(where: { $0.itemID == itemID }) else { return nil }
        return entries.remove(at: index).data
    }

    func cancel() {
        scheduledTask?.cancel()
        scheduledTask = nil
        entries.removeAll()
    }

    /// 仅供单元测试注入预取缓存。
    func seedEntryForTesting(itemID: String, data: Data) {
        entries = [CacheEntry(itemID: itemID, data: data)]
    }

    static func isPrefetchEligible(_ item: FileItem) -> Bool {
        PreviewCapability.isPrefetchEligible(item)
    }

    private func prefetchAdjacent(items: [FileItem], centerIndex: Int) async {
        var newEntries: [CacheEntry] = []

        for offset in [-1, 1] {
            let index = centerIndex + offset
            guard items.indices.contains(index) else { continue }
            let item = items[index]
            guard Self.isPrefetchEligible(item) else { continue }

            let itemID = item.id
            let url = item.url
            let data = await Task.detached(priority: .utility) {
                try? Data(contentsOf: url, options: [.mappedIfSafe])
            }.value

            guard let data, !data.isEmpty else { continue }
            newEntries.append(CacheEntry(itemID: itemID, data: data))
            if newEntries.count >= PreviewBrowserStripMetrics.contentPrefetchMaxBuffers {
                break
            }
        }

        entries = newEntries
    }
}
