import Foundation

@MainActor
final class PreviewBrowserContentPrefetcher {
    private struct CacheEntry {
        let itemID: String
        let data: Data
    }

    private var entries: [CacheEntry] = []
    private var scheduledTask: Task<Void, Never>?

    func schedulePrefetch(items: [FileItem], centerIndex: Int) {
        guard items.indices.contains(centerIndex) else { return }
        guard !DirectorySizeVolumeFilter.isNetworkVolume(path: items[centerIndex].url.path) else {
            cancel()
            return
        }
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: PreviewBrowserStripMetrics.contentPrefetchSettleMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
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
