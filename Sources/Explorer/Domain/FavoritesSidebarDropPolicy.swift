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

    static func canDropOntoFavorite(destinationPath: String, sourcePaths: [String]) -> Bool {
        let destination = (destinationPath as NSString).standardizingPath
        for source in sourcePaths {
            let sourcePath = (source as NSString).standardizingPath
            if FavoritePathNormalization.pathsRepresentSameLocation(sourcePath, destination) {
                return false
            }
            if sourcePath.hasPrefix(destination + "/") {
                return false
            }
        }
        return true
    }

    static func filterAddableDirectoryURLs(
        _ urls: [URL],
        isAlreadyFavorite: (String) -> Bool
    ) -> [URL] {
        urls.filter { url in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  !FileListApplicationBundle.isBundle(path: url.path),
                  !isAlreadyFavorite(url.path) else {
                return false
            }
            return true
        }
    }

    static func destinationPath(for items: [FavoriteItem], pendingDropRow: Int) -> String {
        guard !items.isEmpty else { return "" }
        let row = pendingDropRow < 0 ? 0 : min(pendingDropRow, items.count - 1)
        return items[row].path
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
}
