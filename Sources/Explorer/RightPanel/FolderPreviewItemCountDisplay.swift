import Foundation
import FileList

/// 文件夹预览摘要中的子项数量文案（单一数据源：`DirectoryMetadataOverlay`）。
@MainActor
enum FolderPreviewItemCountDisplay {
    static func resolvedCount(from overlay: DirectoryMetadataOverlay, path: String) -> Int? {
        guard !FileListApplicationBundle.isBundle(path: path) else { return nil }
        let display = overlay.countDisplay(for: path)
        guard display.count >= 0 else { return nil }
        return display.count
    }

    static func summaryText(count: Int?, isApplicationBundle: Bool) -> String {
        if isApplicationBundle {
            return L10n.Preview.Folder.applicationKind
        }
        guard let count else {
            return L10n.Preview.Folder.countingItems
        }
        return L10n.Preview.Folder.itemCount(count)
    }

    static func truncationCaption(maxChildren: Int, totalCount: Int?) -> String {
        guard let totalCount else {
            return "显示前 \(maxChildren) 项"
        }
        return "显示前 \(maxChildren) / \(totalCount) 项"
    }
}
