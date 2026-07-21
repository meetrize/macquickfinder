import Foundation
import FileList

/// 目录列表重载后恢复选中：当前目录项 + 内容搜索等场景下仍存在于磁盘的路径。
enum ListingSelectionRestorer {
    static func restoredIDs(
        preserved: Set<FileItem.ID>,
        loadedItems: [FileItem],
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> Set<FileItem.ID> {
        guard !preserved.isEmpty else { return [] }
        let loadedIDs = Set(loadedItems.map(\.id))
        return preserved.filter { id in
            if loadedIDs.contains(id) { return true }
            guard id != FileItem.parentDirectoryID else { return false }
            return fileExists(id)
        }
    }
}
