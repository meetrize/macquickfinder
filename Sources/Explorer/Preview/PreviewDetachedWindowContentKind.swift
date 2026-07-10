import FileList
import Foundation

/// 独立预览窗 frame 持久化分组键（与 `PreviewStandaloneOpenPreferences` 默认尺寸表对齐）。
enum PreviewDetachedWindowContentKind: String, Codable {
    case image
    case pdf
    case text
    case media
    case office
    case archive
    case other

    static func from(route: PreviewLoadRoute) -> Self {
        switch route {
        case .builtInImage, .builtInQuickLookImage, .customOverride(.image), .customSupplement(.image):
            return .image
        case .builtInPDF, .customOverride(.pdf), .customSupplement(.pdf):
            return .pdf
        case .builtInText, .customOverride(.text), .customOverride(.markdown), .customOverride(.html),
             .epub, .eml, .font,
             .customSupplement(.text), .customSupplement(.markdown), .customSupplement(.html):
            return .text
        case .builtInMedia, .customOverride(.media), .customSupplement(.media):
            return .media
        case .builtInOffice, .docx, .doc, .xlsx, .xls, .csv, .rtf,
             .customOverride(.quickLook), .customSupplement(.quickLook):
            return .office
        case .archive, .customOverride(.archive), .customSupplement(.archive):
            return .archive
        case .unavailable:
            return .other
        }
    }

    @MainActor
    static func from(file: FileItem) -> Self {
        from(route: PreviewStandaloneOpenPreferences.previewLoadRoute(for: file))
    }
}
