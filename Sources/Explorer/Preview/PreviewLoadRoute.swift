import Foundation

/// 内置预览加载路径（与 `PreviewSession+LoadingPipeline` 执行顺序一致）。
enum PreviewLoadRoute: Equatable {
    case customOverride(CustomPreviewMode)
    case builtInImage
    case builtInMedia
    case docx
    case builtInOffice
    case builtInPDF
    case archive
    case builtInText(deferSourceLoad: Bool)
    case customSupplement(CustomPreviewMode)
    case unavailable
}

struct PreviewLoadDispatchInput: Equatable {
    let pathExtension: String
    let fileName: String
    let isHtmlFile: Bool
    let htmlPreviewMode: HtmlDisplayMode
    let overridingMode: CustomPreviewMode?
    let supplementalMode: CustomPreviewMode?
}

enum PreviewLoadDispatch {
    static func resolve(_ input: PreviewLoadDispatchInput) -> PreviewLoadRoute {
        let ext = input.pathExtension.lowercased()

        if let overridingMode = input.overridingMode {
            return .customOverride(overridingMode)
        }
        if BuiltinPreviewExtensions.image.contains(ext) {
            return .builtInImage
        }
        if BuiltinPreviewExtensions.media.contains(ext) {
            return .builtInMedia
        }
        if ext == "docx" {
            return .docx
        }
        if BuiltinPreviewExtensions.office.contains(ext) {
            return .builtInOffice
        }
        if BuiltinPreviewExtensions.pdf.contains(ext) {
            return .builtInPDF
        }
        if ArchivePreviewLoader.isArchiveFileName(input.fileName.lowercased()) {
            return .archive
        }
        if BuiltinPreviewExtensions.text.contains(ext) {
            let deferSource = input.isHtmlFile && input.htmlPreviewMode == .preview
            return .builtInText(deferSourceLoad: deferSource)
        }
        if let supplementalMode = input.supplementalMode {
            return .customSupplement(supplementalMode)
        }
        return .unavailable
    }
}
