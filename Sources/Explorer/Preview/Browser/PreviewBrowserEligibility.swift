import Foundation
import FileList

enum PreviewBrowserEligibility {
    /// 内置 + 归档扩展名判定（不访问 CustomPreviewRuleStore）。
    static func canPreviewBuiltIn(_ file: FileItem) -> Bool {
        PreviewCapability.hasBuiltInPreview(file)
    }

    /// 与独立窗口 `loadContent` 能力对齐，含用户自定义预览规则。
    @MainActor
    static func canPreviewInDetachedWindow(_ file: FileItem) -> Bool {
        PreviewCapability.canLoadPreview(for: file)
    }

    static func matchesSameExtension(_ file: FileItem, as reference: FileItem) -> Bool {
        PreviewCapability.matchesSameExtension(file, as: reference)
    }

    static func filterSameType(_ items: [FileItem], as reference: FileItem) -> [FileItem] {
        PreviewCapability.filterSameType(items, as: reference)
    }
}
