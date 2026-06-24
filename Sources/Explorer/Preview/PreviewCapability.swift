import Foundation
import FileList

/// 预览能力单一来源：能否预览、能否分离窗口、能否目录浏览、能否预取等。
enum PreviewCapability {
    /// 内置扩展名 + 压缩包（不读自定义规则）。
    static func hasBuiltInPreview(_ file: FileItem) -> Bool {
        guard isPreviewableFileEntry(file) else { return false }
        let ext = file.url.pathExtension.lowercased()
        if BuiltinPreviewExtensions.matchesBuiltIn(ext) { return true }
        if BuiltinPreviewExtensions.matchesArchive(fileName: file.name) { return true }
        return false
    }

    /// 与 `PreviewSession.loadContent` / 独立窗口加载能力对齐（含自定义规则）。
    @MainActor
    static func canLoadPreview(for file: FileItem) -> Bool {
        guard isPreviewableFileEntry(file) else { return false }
        if hasBuiltInPreview(file) { return true }
        let ext = file.url.pathExtension.lowercased()
        return CustomPreviewRuleStore.shared.activeMode(for: ext) != nil
    }

    /// 目录内胶片条 / 浏览上下文候选过滤。
    @MainActor
    static func isBrowserCandidate(_ file: FileItem, showHiddenFiles: Bool) -> Bool {
        guard !file.isParentDirectoryEntry, !file.isDirectory else { return false }
        if !showHiddenFiles, file.isHidden { return false }
        return canLoadPreview(for: file)
    }

    /// 侧栏预览是否可弹出到独立窗口。
    @MainActor
    static func canDetach(session: PreviewSession, selectedItem: FileItem) -> Bool {
        guard session.previewContentItem != nil else { return false }
        if selectedItem.isDirectory, session.folderInlineChild == nil { return false }
        return !session.location.isDetached
    }

    /// 与参考文件扩展名一致（不含 `.`，空扩展名仅匹配空扩展名）。
    static func matchesSameExtension(_ file: FileItem, as reference: FileItem) -> Bool {
        file.url.pathExtension.lowercased() == reference.url.pathExtension.lowercased()
    }

    /// 同类型过滤：在已通过 detached 预览判定的前提下，保留与参考文件同扩展名的项。
    static func filterSameType(_ items: [FileItem], as reference: FileItem) -> [FileItem] {
        items.filter { matchesSameExtension($0, as: reference) }
    }

    /// 小体积图片 / PDF 可预取（供胶片条缩略图）。
    static func isPrefetchEligible(_ file: FileItem) -> Bool {
        guard isPreviewableFileEntry(file) else { return false }
        let ext = file.url.pathExtension.lowercased()
        guard BuiltinPreviewExtensions.image.contains(ext)
            || BuiltinPreviewExtensions.pdf.contains(ext) else {
            return false
        }
        return file.size > 0 && file.size <= PreviewBrowserStripMetrics.contentPrefetchMaxFileSize
    }

    private static func isPreviewableFileEntry(_ file: FileItem) -> Bool {
        !file.isDirectory && !file.isParentDirectoryEntry
    }
}
