import Foundation
import FileList

/// 悬停预览资格：与侧栏 `canLoadPreview` 对齐，并处理侧栏同文件跳过。
enum HoverPreviewEligibility {
    @MainActor
    static func shouldShow(
        for file: FileItem,
        rightPanelVisible: Bool,
        rightPanelURL: URL?
    ) -> Bool {
        guard PreviewCapability.canLoadPreview(for: file) else { return false }
        if rightPanelVisible, let rightPanelURL, urlsMatch(file.url, rightPanelURL) {
            return false
        }
        return true
    }

    /// FileList 行级快速过滤（不读自定义规则；完整判定仍走 `shouldShow`）。
    static func isCandidateRow(_ row: FileListRow) -> Bool {
        !row.isDirectory && !row.isParentDirectoryEntry
    }

    private static func urlsMatch(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }
}
