import AppKit
import FileList
import Foundation

struct PanoramaThumbnailLoadRequest: Equatable, Sendable {
    let orderedRowIDs: [String]
    let rowsByID: [String: FileListRow]
    let visibleRowIDs: Set<String>
    let cellSize: CGFloat
    let screenScale: CGFloat
    let preferWorkspaceIcons: Bool

    init(
        orderedRowIDs: [String],
        rowsByID: [String: FileListRow],
        visibleRowIDs: Set<String>,
        cellSize: CGFloat,
        screenScale: CGFloat,
        preferWorkspaceIcons: Bool = false
    ) {
        self.orderedRowIDs = orderedRowIDs
        self.rowsByID = rowsByID
        self.visibleRowIDs = visibleRowIDs
        self.cellSize = cellSize
        self.screenScale = screenScale
        self.preferWorkspaceIcons = preferWorkspaceIcons
    }
}

/// 多 grid 可见窗口缩略图调度，共用全局 `ThumbnailGenerator`。
@MainActor
final class PanoramaThumbnailScheduler: ObservableObject {
    @Published private(set) var imageByRowID: [String: NSImage] = [:]

    private let generator = ThumbnailGenerator.shared
    private var loadGeneration: UInt = 0
    private var activeRequest: PanoramaThumbnailLoadRequest?

    private static let batchSize = 8

    func update(_ request: PanoramaThumbnailLoadRequest) {
        loadGeneration &+= 1
        let generation = loadGeneration
        activeRequest = request
        generator.cancelInFlightRequests()

        let indicesToLoad = prefetchIndices(for: request)
        let allowedIDs: Set<String> = Set(
            indicesToLoad.compactMap { index in
                guard request.orderedRowIDs.indices.contains(index) else { return nil }
                return request.orderedRowIDs[index]
            }
        )

        imageByRowID = imageByRowID.filter { allowedIDs.contains($0.key) }

        guard !indicesToLoad.isEmpty else { return }

        loadBatch(
            indices: indicesToLoad.sorted(),
            request: request,
            generation: generation,
            start: 0
        )
    }

    func image(for rowID: String) -> NSImage? {
        imageByRowID[rowID]
    }

    func shutdown() {
        loadGeneration &+= 1
        activeRequest = nil
        generator.cancelInFlightRequests()
        imageByRowID.removeAll()
    }

    func respondToMemoryPressure() {
        loadGeneration &+= 1
        generator.cancelInFlightRequests()
        imageByRowID.removeAll()
    }

    // MARK: - Private

    private func prefetchIndices(for request: PanoramaThumbnailLoadRequest) -> Set<Int> {
        guard !request.visibleRowIDs.isEmpty else { return [] }

        let radius: Int
        if request.preferWorkspaceIcons {
            radius = 0
        } else if request.orderedRowIDs.contains(where: { rowID in
            guard request.visibleRowIDs.contains(rowID), let row = request.rowsByID[rowID] else { return false }
            return DirectorySizeVolumeFilter.isNetworkVolume(path: row.iconPath)
        }) {
            radius = 0
        } else {
            radius = PanoramaMetrics.thumbnailPrefetchRadius
        }

        var indices = Set<Int>()
        for (index, rowID) in request.orderedRowIDs.enumerated() where request.visibleRowIDs.contains(rowID) {
            for offset in -radius...radius {
                let target = index + offset
                if request.orderedRowIDs.indices.contains(target) {
                    indices.insert(target)
                }
            }
        }
        return indices
    }

    private func loadBatch(
        indices: [Int],
        request: PanoramaThumbnailLoadRequest,
        generation: UInt,
        start: Int
    ) {
        guard generation == loadGeneration else { return }

        let end = min(start + Self.batchSize, indices.count)
        for position in start..<end {
            let index = indices[position]
            guard request.orderedRowIDs.indices.contains(index) else { continue }
            let rowID = request.orderedRowIDs[index]
            guard let row = request.rowsByID[rowID] else { continue }
            loadThumbnail(for: row, request: request, generation: generation)
        }

        guard end < indices.count else { return }
        DispatchQueue.main.async { [weak self] in
            self?.loadBatch(
                indices: indices,
                request: request,
                generation: generation,
                start: end
            )
        }
    }

    private func loadThumbnail(
        for row: FileListRow,
        request: PanoramaThumbnailLoadRequest,
        generation: UInt
    ) {
        if row.isParentDirectoryEntry {
            let icon = generator.instantPlaceholder(
                for: row,
                cellSize: request.cellSize,
                screenScale: request.screenScale
            )
            imageByRowID[row.id] = icon
            return
        }

        if request.preferWorkspaceIcons {
            let icon = FileListWorkspaceIconCache.icon(forPath: row.iconPath)
            imageByRowID[row.id] = FileListThumbnailMetrics.scaledIcon(icon, cellSize: request.cellSize)
            return
        }

        if let cached = generator.cachedThumbnailImage(for: row, cellSize: request.cellSize) {
            imageByRowID[row.id] = cached
            return
        }

        if imageByRowID[row.id] == nil {
            imageByRowID[row.id] = generator.instantPlaceholder(
                for: row,
                cellSize: request.cellSize,
                screenScale: request.screenScale
            )
        }

        generator.load(
            for: row,
            cellSize: request.cellSize,
            screenScale: request.screenScale
        ) { [weak self] delivery in
            Task { @MainActor in
                guard let self, generation == self.loadGeneration else { return }
                switch delivery {
                case let .thumbnail(image), let .icon(image):
                    self.imageByRowID[row.id] = image
                }
            }
        }
    }
}

#if DEBUG
extension PanoramaThumbnailScheduler {
    var trackedRowCountForTesting: Int {
        imageByRowID.count
    }
}
#endif
