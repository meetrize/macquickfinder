import AppKit
import AVFoundation
import Foundation
import PDFKit

/// 单次预览加载的结果快照，由 pipeline 构造后交给 `PreviewSession.applyLoadPayload`。
struct PreviewLoadPayload {
    var imageData: Data?
    var pdfData: Data?
    var mediaURL: URL?
    var officeURL: URL?
    var officeRichText: NSAttributedString?
    var archiveEntries: [ArchiveEntryPreview]?
    var archiveTruncated = false
    var textContent: String?
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

    static func failure(_ message: String) -> PreviewLoadPayload {
        PreviewLoadPayload(error: message)
    }
}
