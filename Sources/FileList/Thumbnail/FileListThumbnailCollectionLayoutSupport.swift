import AppKit

/// 缩略图网格布局查询：避免框选/命中测试时对全部 item 调用 `layoutAttributesForItem`。
enum FileListThumbnailCollectionLayoutSupport {
    static func indexPaths(intersecting rect: NSRect, in collectionView: NSCollectionView) -> Set<IndexPath> {
        if let layout = collectionView.collectionViewLayout {
            let attributes = layout.layoutAttributesForElements(in: rect)
            let paths = Set(attributes.compactMap { $0.indexPath })
            if !paths.isEmpty {
                return paths
            }
        }

        var result = Set<IndexPath>()
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else { continue }
            if frame.intersects(rect) {
                result.insert(indexPath)
            }
        }
        return result
    }

    static func indexPath(at point: NSPoint, in collectionView: NSCollectionView) -> IndexPath? {
        if let indexPath = collectionView.indexPathForItem(at: point) {
            return indexPath
        }

        let probe = NSRect(
            x: point.x - 1,
            y: point.y - 1,
            width: 2,
            height: 2
        )
        let candidates = indexPaths(intersecting: probe, in: collectionView)
        var bestMatch: (indexPath: IndexPath, area: CGFloat)?
        for indexPath in candidates {
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else { continue }
            guard frame.contains(point) else { continue }
            let area = frame.width * frame.height
            if bestMatch == nil || area < bestMatch!.area {
                bestMatch = (indexPath, area)
            }
        }
        return bestMatch?.indexPath
    }

    /// Shift 多选：在网格行主序下选取锚点与目标之间的矩形区域。
    static func indexPathsInGridRect(
        anchorItem: Int,
        targetItem: Int,
        columnCount: Int,
        itemCount: Int
    ) -> Set<IndexPath> {
        let columns = max(1, columnCount)
        let anchorRow = anchorItem / columns
        let anchorCol = anchorItem % columns
        let targetRow = targetItem / columns
        let targetCol = targetItem % columns
        let minRow = min(anchorRow, targetRow)
        let maxRow = max(anchorRow, targetRow)
        let minCol = min(anchorCol, targetCol)
        let maxCol = max(anchorCol, targetCol)

        var result = Set<IndexPath>()
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                let index = row * columns + col
                guard index >= 0, index < itemCount else { continue }
                result.insert(IndexPath(item: index, section: 0))
            }
        }
        return result
    }

    static func smallestIndexPath(containing point: NSPoint, in collectionView: NSCollectionView) -> IndexPath? {
        let probe = NSRect(
            x: point.x - 1,
            y: point.y - 1,
            width: 2,
            height: 2
        )
        let candidates = indexPaths(intersecting: probe, in: collectionView)
        var bestMatch: (indexPath: IndexPath, area: CGFloat)?
        for indexPath in candidates {
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else { continue }
            guard frame.contains(point) else { continue }
            let area = frame.width * frame.height
            if bestMatch == nil || area < bestMatch!.area {
                bestMatch = (indexPath, area)
            }
        }
        return bestMatch?.indexPath
    }
}
