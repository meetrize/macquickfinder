import AppKit
import FileList
import Foundation

@MainActor
final class PreviewBrowserStripThumbnailLoader: ObservableObject {
    @Published private(set) var imageByItemID: [String: NSImage] = [:]

    private let generator = ThumbnailGenerator.shared
    private var loadGeneration: UInt = 0

    func updatePrefetchWindow(items: [FileItem], centerIndex: Int, screenScale: CGFloat) {
        loadGeneration &+= 1
        let generation = loadGeneration
        generator.cancelInFlightRequests()

        guard items.indices.contains(centerIndex) else {
            imageByItemID.removeAll()
            return
        }

        let isNetworkVolume = DirectorySizeVolumeFilter.isNetworkVolume(
            path: items[centerIndex].url.path
        )
        let radius = isNetworkVolume ? 0 : PreviewBrowserStripMetrics.thumbnailPrefetchRadius
        let cellSize = PreviewBrowserStripMetrics.thumbnailSize

        var indicesToLoad = Set<Int>()
        for offset in -radius...radius {
            let index = centerIndex + offset
            if items.indices.contains(index) {
                indicesToLoad.insert(index)
            }
        }

        let allowedIDs = Set(indicesToLoad.map { items[$0].id })
        imageByItemID = imageByItemID.filter { allowedIDs.contains($0.key) }

        for index in indicesToLoad.sorted() {
            let item = items[index]
            let row = FileListRow(item: item)

            if let cached = generator.cachedThumbnailImage(for: row, cellSize: cellSize) {
                imageByItemID[item.id] = cached
                continue
            }

            if imageByItemID[item.id] == nil {
                imageByItemID[item.id] = generator.instantPlaceholder(
                    for: row,
                    cellSize: cellSize,
                    screenScale: screenScale
                )
            }

            generator.load(for: row, cellSize: cellSize, screenScale: screenScale) { [weak self] (delivery: ThumbnailGenerator.Delivery) in
                Task { @MainActor in
                    guard let self, generation == self.loadGeneration else { return }
                    switch delivery {
                    case .thumbnail(let image), .icon(let image):
                        self.imageByItemID[item.id] = image
                    }
                }
            }
        }
    }

    func image(for itemID: String) -> NSImage? {
        imageByItemID[itemID]
    }

    func shutdown() {
        loadGeneration &+= 1
        generator.cancelInFlightRequests()
        imageByItemID.removeAll()
    }

    /// 系统内存压力：释放条带内已解码图像；共享 LRU 由全局 handler 清理。
    func respondToMemoryPressure() {
        loadGeneration &+= 1
        generator.cancelInFlightRequests()
        imageByItemID.removeAll()
    }
}
