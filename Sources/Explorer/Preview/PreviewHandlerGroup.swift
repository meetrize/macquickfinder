import Foundation
import UniformTypeIdentifiers

/// 可注册为系统默认打开程序的分组（Launch Services）。
enum PreviewHandlerGroup: String, CaseIterable, Identifiable, Codable {
    case image
    case pdf
    case textAndCode
    case media
    case office

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .image:
            return L10n.Settings.Preview.HandlerGroup.image
        case .pdf:
            return L10n.Settings.Preview.HandlerGroup.pdf
        case .textAndCode:
            return L10n.Settings.Preview.HandlerGroup.textAndCode
        case .media:
            return L10n.Settings.Preview.HandlerGroup.media
        case .office:
            return L10n.Settings.Preview.HandlerGroup.office
        }
    }

    var managedContentTypes: [UTType] {
        switch self {
        case .image:
            return DefaultPreviewHandlerManager.imageContentTypes
        case .pdf:
            return Self.uniqueTypes(
                broad: [.pdf],
                extensions: BuiltinPreviewExtensions.pdf
            )
        case .textAndCode:
            return Self.uniqueTypes(
                broad: [.plainText, .sourceCode, .text, .json, .xml, .yaml],
                extensions: BuiltinPreviewExtensions.text
            )
        case .media:
            return Self.uniqueTypes(
                broad: [.movie, .audio, .mpeg4Movie, .mpeg4Audio, .mp3, .wav, .quickTimeMovie],
                extensions: BuiltinPreviewExtensions.media
            )
        case .office:
            return Self.uniqueTypes(
                broad: [],
                extensions: BuiltinPreviewExtensions.office
            )
        }
    }

    var representativeContentType: UTType {
        switch self {
        case .image:
            return .jpeg
        case .pdf:
            return .pdf
        case .textAndCode:
            return .plainText
        case .media:
            return .mpeg4Movie
        case .office:
            return UTType(filenameExtension: "docx") ?? .data
        }
    }

    var systemFallbackBundleIdentifier: String {
        switch self {
        case .image, .pdf, .office:
            return DefaultPreviewHandlerManager.previewBundleIdentifier
        case .textAndCode:
            return "com.apple.TextEdit"
        case .media:
            return "com.apple.QuickTimePlayerX"
        }
    }

    private static func uniqueTypes(broad: [UTType], extensions: Set<String>) -> [UTType] {
        var types: [UTType] = []
        var seen = Set<String>()
        for type in broad {
            if seen.insert(type.identifier).inserted {
                types.append(type)
            }
        }
        for ext in extensions {
            guard let type = UTType(filenameExtension: ext) else { continue }
            if seen.insert(type.identifier).inserted {
                types.append(type)
            }
        }
        return types
    }
}
