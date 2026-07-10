import CoreGraphics
import FileList
import Foundation

/// 子目录全景缩略图布局与加载常量。
enum PanoramaMetrics {
    static let indentStep: CGFloat = 20
    static let headerHeight: CGFloat = 32
    static let sectionVerticalSpacing: CGFloat = 8
    static let gridSpacing: CGFloat = FileListThumbnailMetrics.cellSpacing
    static let gridContentInset: CGFloat = FileListThumbnailMetrics.contentInset
    static let itemsPerGridCap = 48
    static let thumbnailPrefetchRadius = 2
    static let visibilityDebounce: TimeInterval = 0.08
    static let bootstrapBatchSize = 4
    static let maxCachedDirectoryListings = 32
    static let bootstrapPriorityDepth = 2

    /// 目录标题行左侧缩进。
    static func leadingPadding(forDepth depth: Int) -> CGFloat {
        CGFloat(max(0, depth)) * indentStep
    }

    /// 与标准缩略图网格一致的左内边距（depth 缩进 + contentInset）。
    static func contentLeadingInset(forDepth depth: Int) -> CGFloat {
        leadingPadding(forDepth: depth) + gridContentInset
    }

    static var contentTrailingInset: CGFloat { gridContentInset }

    /// 网格可用宽度（扣除缩进与内边距）。
    static func gridAvailableWidth(viewportWidth: CGFloat, depth: Int) -> CGFloat {
        max(
            0,
            viewportWidth - leadingPadding(forDepth: depth) - gridContentInset * 2
        )
    }

    /// 与标准缩略图网格一致的列数计算。
    static func gridColumnCount(availableWidth: CGFloat, cellSize: CGFloat) -> Int {
        let stepped = FileListThumbnailMetrics.steppedCellSize(from: cellSize)
        let unit = stepped + gridSpacing
        guard unit > 0 else { return 1 }
        return max(1, Int((availableWidth + gridSpacing) / unit))
    }

    /// 目录路径稳定色条色相（0…360）。
    static func accentHue(forPath path: String) -> Double {
        var hash: UInt64 = 5381
        for byte in path.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return Double(hash % 360)
    }

    /// 将完整 listing 切片为网格展示项，并在超出 cap 时追加 overflow。
    static func cappedGridItems(
        files: [FileListRow],
        collapsedFolders: [FileListRow],
        directoryID: String,
        cap: Int = itemsPerGridCap
    ) -> [PanoramaGridItem] {
        guard cap > 0 else { return [] }

        var allItems: [PanoramaGridItem] = []
        allItems.reserveCapacity(collapsedFolders.count + files.count)
        allItems.append(contentsOf: collapsedFolders.map { .folderCollapsed($0) })
        allItems.append(contentsOf: files.map { .file($0) })

        let total = allItems.count
        guard total > cap else { return allItems }

        let visibleCount = max(0, cap - 1)
        var result = Array(allItems.prefix(visibleCount))
        result.append(.overflow(directoryID: directoryID, remaining: total - visibleCount))
        return result
    }
}
