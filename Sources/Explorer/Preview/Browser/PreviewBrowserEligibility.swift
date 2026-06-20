import Foundation

enum PreviewBrowserEligibility {
    /// 内置 + 归档扩展名判定（不访问 CustomPreviewRuleStore）。
    static func canPreviewBuiltIn(_ file: FileItem) -> Bool {
        guard !file.isDirectory, !file.isParentDirectoryEntry else { return false }
        let ext = file.url.pathExtension.lowercased()
        if BuiltinPreviewExtensions.matchesBuiltIn(ext) { return true }
        if BuiltinPreviewExtensions.matchesArchive(fileName: file.name) { return true }
        return false
    }

    /// 与独立窗口 `loadContent` 能力对齐，含用户自定义预览规则。
    @MainActor
    static func canPreviewInDetachedWindow(_ file: FileItem) -> Bool {
        guard !file.isDirectory, !file.isParentDirectoryEntry else { return false }
        let ext = file.url.pathExtension.lowercased()
        if BuiltinPreviewExtensions.matchesBuiltIn(ext) { return true }
        if BuiltinPreviewExtensions.matchesArchive(fileName: file.name) { return true }
        if CustomPreviewRuleStore.shared.activeMode(for: ext) != nil { return true }
        return false
    }

    /// 与参考文件扩展名一致（不含 `.`，空扩展名仅匹配空扩展名）。
    static func matchesSameExtension(_ file: FileItem, as reference: FileItem) -> Bool {
        file.url.pathExtension.lowercased() == reference.url.pathExtension.lowercased()
    }

    /// 同类型过滤：在已通过 detached 预览判定的前提下，保留与参考文件同扩展名的项。
    static func filterSameType(_ items: [FileItem], as reference: FileItem) -> [FileItem] {
        items.filter { matchesSameExtension($0, as: reference) }
    }
}
