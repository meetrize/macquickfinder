import AppKit
import CoreFoundation
import CoreText
import Foundation

struct FontPreviewMetadata: Equatable {
    let familyName: String
    let fullName: String
    let styleName: String?
    let postScriptName: String?
    let version: String?
    let copyright: String?
    let glyphCount: Int
}

struct FontPreviewContent: Equatable {
    let metadata: FontPreviewMetadata
    let sourcePath: String
    let postScriptName: String

    var sourceURL: URL {
        URL(fileURLWithPath: sourcePath)
    }
}

/// 使用 CoreText 从 `.ttf` / `.otf` 提取字体元数据。
enum FontPreviewLoader {
    static let sampleSizes: [CGFloat] = [12, 24, 48, 72]
    static let englishSample = "The quick brown fox jumps over the lazy dog."
    static let chineseSample = "天地玄黄 宇宙洪荒 日月盈昃 辰宿列张"

    static func load(from url: URL) throws -> FontPreviewContent {
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        guard let descriptor = descriptors?.first else {
            throw LoaderError.unableToLoad
        }

        let ctFont = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        let postScriptName = (CTFontCopyPostScriptName(ctFont) as String?)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        let metadata = FontPreviewMetadata(
            familyName: fontName(ctFont, key: kCTFontFamilyNameKey) ?? url.deletingPathExtension().lastPathComponent,
            fullName: fontName(ctFont, key: kCTFontFullNameKey) ?? url.lastPathComponent,
            styleName: fontName(ctFont, key: kCTFontStyleNameKey),
            postScriptName: postScriptName,
            version: fontName(ctFont, key: kCTFontVersionNameKey),
            copyright: fontName(ctFont, key: kCTFontCopyrightNameKey),
            glyphCount: max(0, CTFontGetGlyphCount(ctFont))
        )

        guard let postScriptName, !postScriptName.isEmpty else {
            throw LoaderError.unableToLoad
        }

        return FontPreviewContent(
            metadata: metadata,
            sourcePath: url.path,
            postScriptName: postScriptName
        )
    }

    static func registerFontForPreview(at url: URL) throws {
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        guard ok else {
            throw LoaderError.unableToLoad
        }
    }

    static func unregisterFontForPreview(at url: URL) {
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
    }

    private static func fontName(_ font: CTFont, key: CFString) -> String? {
        guard let value = CTFontCopyName(font, key) as String? else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    enum LoaderError: LocalizedError {
        case unableToLoad

        var errorDescription: String? {
            L10n.Error.Font.unableToLoad
        }
    }
}
