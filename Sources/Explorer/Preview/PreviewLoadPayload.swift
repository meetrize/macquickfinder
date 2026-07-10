import AppKit
import AVFoundation
import Foundation
import PDFKit

/// 单次预览加载的结果快照，由 pipeline 构造后交给 `PreviewSession.applyLoadPayload`。
struct PreviewLoadPayload {
    var imageData: Data?
    /// 图片降采样最长边；nil 表示按会话默认显示预算或全分辨率。
    var imageMaxPixelSize: Int?
    var pdfData: Data?
    var mediaURL: URL?
    var officeURL: URL?
    var officeRichText: NSAttributedString?
    var archiveEntries: [ArchiveEntryPreview]?
    var archiveTruncated = false
    var textContent: String?
    var epubPackage: EpubPreviewPackage?
    var emlContent: EmlPreviewContent?
    var fontContent: FontPreviewContent?
    var error: String?

    static let unavailable = PreviewLoadPayload()

    static func media(url: URL) -> PreviewLoadPayload {
        PreviewLoadPayload(mediaURL: url)
    }

    static func office(url: URL) -> PreviewLoadPayload {
        PreviewLoadPayload(officeURL: url)
    }

    static func officeRichText(_ richText: NSAttributedString) -> PreviewLoadPayload {
        PreviewLoadPayload(officeRichText: richText)
    }

    static func archive(entries: [ArchiveEntryPreview], truncated: Bool) -> PreviewLoadPayload {
        PreviewLoadPayload(archiveEntries: entries, archiveTruncated: truncated)
    }

    static func text(_ content: String) -> PreviewLoadPayload {
        PreviewLoadPayload(textContent: content)
    }

    static func spreadsheetText(_ content: String, officeURL: URL) -> PreviewLoadPayload {
        PreviewLoadPayload(officeURL: officeURL, textContent: content)
    }

    static func wordDocument(text content: String, richText: NSAttributedString) -> PreviewLoadPayload {
        PreviewLoadPayload(officeRichText: richText, textContent: content)
    }

    static func epub(_ package: EpubPreviewPackage) -> PreviewLoadPayload {
        PreviewLoadPayload(epubPackage: package)
    }

    static func eml(_ content: EmlPreviewContent) -> PreviewLoadPayload {
        PreviewLoadPayload(emlContent: content)
    }

    static func font(_ content: FontPreviewContent) -> PreviewLoadPayload {
        PreviewLoadPayload(fontContent: content)
    }

    static func failure(_ message: String) -> PreviewLoadPayload {
        PreviewLoadPayload(error: message)
    }
}
