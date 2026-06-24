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
            return "— 项"
        }
        guard let count else {
            return "正在统计…"
        }
        return "\(count) 项"
    }

    static func truncationCaption(maxChildren: Int, totalCount: Int?) -> String {
        guard let totalCount else {
            return "显示前 \(maxChildren) 项"
        }
        return "显示前 \(maxChildren) / \(totalCount) 项"
    }
}
