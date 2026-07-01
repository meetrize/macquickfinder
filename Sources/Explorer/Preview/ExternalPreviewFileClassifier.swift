import Foundation
import FileList

/// 外部入口（Finder 双击、打开方式等）可独立预览文件的 URL 分类。
@MainActor
enum ExternalPreviewFileClassifier {
    /// 与 `PreviewBrowserEligibility.canPreviewInDetachedWindow` / `PreviewCapability.canLoadPreview` 对齐。
    static func isExternalPreviewCandidate(_ url: URL) -> Bool {
        guard !isDirectoryURL(url) else { return false }
        guard let item = fileItemForClassification(url: url) else { return false }
        return PreviewCapability.canLoadPreview(for: item)
    }

    static func previewableURLs(from urls: [URL]) -> [URL] {
        urls.filter(isExternalPreviewCandidate)
    }

    private static func isDirectoryURL(_ url: URL) -> Bool {
        if url.hasDirectoryPath { return true }
        var isDirectory: ObjCBool = false
        let path = url.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }

    private static func fileItemForClassification(url: URL) -> FileItem? {
        FileItem.resolveSelection(ids: [url.path], from: []).first
    }
}

/// 仅图片类扩展名（供尚未迁移至 `ExternalPreviewFileClassifier` 的调用方使用）。
enum ExternalImageFileClassifier {
    static func isExternalImagePreviewCandidate(_ url: URL) -> Bool {
        guard !url.hasDirectoryPath else { return false }
        let ext = url.pathExtension.lowercased()
        if BuiltinPreviewExtensions.image.contains(ext) { return true }
        if BuiltinPreviewExtensions.quickLookImage.contains(ext) { return true }
        return false
    }

    static func imageURLs(from urls: [URL]) -> [URL] {
        urls.filter(isExternalImagePreviewCandidate)
    }
}
