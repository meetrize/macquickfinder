import Foundation
import FileList

/// 收藏夹侧栏拖放与重排的纯逻辑（无 AppKit 依赖，可单元测试）。
enum FavoritesSidebarDropPolicy {
    static func insertBeforeIndex(
        locationY: CGFloat,
        rowAtLocation row: Int,
        rowCount: Int,
        rowMidY: CGFloat?
    ) -> Int {
        guard rowCount > 0 else { return 0 }
        if row < 0 { return rowCount }
        guard let rowMidY else { return min(row + 1, rowCount) }
        return locationY < rowMidY ? row : row + 1
    }

    static func isDropOntoRowCenter(
        locationY: CGFloat,
        rowMinY: CGFloat,
        rowHeight: CGFloat
    ) -> Bool {
        guard rowHeight > 0 else { return false }
        let edgeBand = min(rowHeight * 0.25, 4)
        let relativeY = locationY - rowMinY
        return relativeY >= edgeBand && relativeY <= rowHeight - edgeBand
    }

    /// 是否把当前落点当作「移入该收藏行」（否则走插入收藏位）。
    /// - 拖入可收藏目录时：仅行中央为移入，上下边缘留给插入横线。
    /// - 仅拖文件/不可收藏项时：可移入则整行有效，便于落点；否则中央仅作无效反馈。
    static func shouldTreatAsDropOntoFavoriteRow(
        hasAddableDirectories: Bool,
        isOntoRowCenter: Bool,
        canDropOntoRow: Bool
    ) -> Bool {
        if hasAddableDirectories {
            return isOntoRowCenter
        }
        if canDropOntoRow {
            return true
        }
        return isOntoRowCenter
    }

    static func canDropOntoFavorite(destinationPath: String, sourcePaths: [String]) -> Bool {
        FavoritePathNormalization.moveBlockReason(moving: sourcePaths, to: destinationPath) == nil
    }

    static func filterAddableDirectoryURLs(
        _ urls: [URL],
        isAlreadyFavorite: (String) -> Bool
    ) -> [URL] {
        urls.filter { url in
            FileListApplicationBundle.isFavoriteableDirectory(path: url.path)
                && !isAlreadyFavorite(url.path)
        }
    }

    static func destinationPath(for items: [FavoriteItem], pendingDropRow: Int) -> String {
        guard pendingDropRow >= 0, pendingDropRow < items.count else { return "" }
        return items[pendingDropRow].resolvedDirectoryPath
    }

    static func clampedInsertIndex(_ insertBefore: Int, itemCount: Int) -> Int {
        min(max(insertBefore, 0), itemCount)
    }

    static func shouldRejectReorder(
        draggedPath: String,
        ontoTargetPath targetPath: String
    ) -> Bool {
        FavoritePathNormalization.pathsRepresentSameLocation(draggedPath, targetPath)
    }

    /// `prepareForDragOperation` 是否应接受当前拖放。
    /// 收藏夹行重排只带自定义 pasteboard 类型、没有 file URL；若此处误拒，AppKit 不会调用 `performDragOperation`。
    static func shouldPrepareDrop(
        isReorderDrag: Bool,
        hasFileURLs: Bool,
        pendingInsertBeforeIndex: Int,
        canDropOntoEffectiveRow: Bool
    ) -> Bool {
        if isReorderDrag {
            return pendingInsertBeforeIndex >= 0
        }
        guard hasFileURLs else { return false }
        if pendingInsertBeforeIndex >= 0 { return true }
        return canDropOntoEffectiveRow
    }
}
