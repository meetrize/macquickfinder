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
        guard !item.isDirectory else { return false }
        guard item.size > 0, item.size <= PreviewBrowserStripMetrics.contentPrefetchMaxFileSize else { return false }
        let ext = item.url.pathExtension.lowercased()
        return BuiltinPreviewExtensions.image.contains(ext) || BuiltinPreviewExtensions.pdf.contains(ext)
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
