import Foundation
import FileList

/// 收藏夹侧栏外部文件拖入的处理（添加收藏 / 移入目录 / 废纸篓）。
@MainActor
enum FavoritesSidebarDropHandler {
    static func handle(
        urls: [URL],
        to destinationPath: String,
        copy: Bool,
        insertBefore: Int?,
        favoritesStore: FavoritesStore,
        onItemsChanged: @escaping () -> Void
    ) {
        var filesToMove: [URL] = []

        if let insertBefore {
            var nextInsertIndex = insertBefore
            for url in urls {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                    continue
                }
                if isDirectory.boolValue, !FileListApplicationBundle.isBundle(path: url.path) {
                    let previousCount = favoritesStore.items.count
                    favoritesStore.addDirectory(at: url.path, insertBefore: nextInsertIndex)
                    if favoritesStore.items.count > previousCount {
                        nextInsertIndex += 1
                    }
                } else {
                    filesToMove.append(url)
                }
            }
        } else {
            for url in urls {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                    continue
                }
                filesToMove.append(url)
            }
        }

        guard !filesToMove.isEmpty else {
            if insertBefore == nil, !urls.isEmpty {
                FileOperations.presentMoveBlockedAlert(.sourceMissing)
            }
            return
        }
        if TrashLoader.isTrashPath(destinationPath) {
            FileOperations.trashItems(filesToMove, completion: onItemsChanged)
            return
        }
        if let reason = FavoritePathNormalization.moveBlockReason(
            moving: filesToMove.map(\.path),
            to: destinationPath
        ) {
            FileOperations.presentMoveBlockedAlert(reason)
            return
        }
        let destination = URL(fileURLWithPath: destinationPath, isDirectory: true)
        FileOperations.moveItems(filesToMove, to: destination, copy: copy, completion: onItemsChanged)
    }
}
