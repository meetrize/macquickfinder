import Foundation
import FileList

enum PreviewTextEditDenialReason: Equatable {
    case notTextFile
    case notUsingTextFilePreview
    case notLoaded
    case contentTruncated
    case notWritable
}

@MainActor
enum PreviewTextEditEligibility {
    static func canEdit(file: FileItem, session: PreviewSession) -> Bool {
        denialReason(for: file, session: session) == nil
    }

    /// 工具栏是否显示「编辑」（含 Markdown 渲染模式下可切源码后编辑）。
    static func canOfferEdit(file: FileItem, session: PreviewSession) -> Bool {
        if canEdit(file: file, session: session) { return true }
        let ext = file.url.pathExtension.lowercased()
        guard PreviewTypeClassifier.isMarkdownFile(ext),
              session.text.markdownMode == .preview else {
            return false
        }
        return contentDenialReason(for: file, session: session) == nil
    }

    static func denialReason(for file: FileItem, session: PreviewSession) -> PreviewTextEditDenialReason? {
        if let contentReason = contentDenialReason(for: file, session: session) {
            return contentReason
        }
        guard usesTextFilePreviewView(file: file, session: session) else {
            return .notUsingTextFilePreview
        }
        return nil
    }

    private static func contentDenialReason(
        for file: FileItem,
        session: PreviewSession
    ) -> PreviewTextEditDenialReason? {
        let ext = file.url.pathExtension.lowercased()
        guard PreviewTypeClassifier.isTextFile(ext) else {
            return .notTextFile
        }
        guard session.content.loadPhase == .loaded else {
            return .notLoaded
        }
        guard !isContentTruncated(session.content.textContent) else {
            return .contentTruncated
        }
        guard FileManager.default.isWritableFile(atPath: file.url.path) else {
            return .notWritable
        }
        return nil
    }

    static func isContentTruncated(_ content: String) -> Bool {
        content.contains(TextFilePreviewReader.truncationMarker)
    }

    /// 是否应展示内置文本 / Markdown 预览（含空文件；不含 HTML 渲染模式）。
    static func showsTextPreviewContent(file: FileItem, session: PreviewSession) -> Bool {
        if !session.content.textContent.isEmpty {
            return true
        }
        guard session.content.loadPhase == .loaded else { return false }
        let ext = file.url.pathExtension.lowercased()
        if PreviewTypeClassifier.isHtmlFile(ext), session.text.htmlMode == .preview {
            return false
        }
        return PreviewDetachedWindowContentKind.from(file: file) == .text
    }

    static func usesTextFilePreviewView(file: FileItem, session: PreviewSession) -> Bool {
        let ext = file.url.pathExtension.lowercased()

        if session.content.image != nil { return false }
        if session.content.pdfDocument != nil { return false }
        if session.content.mediaPlayer != nil { return false }
        if !session.content.archiveEntries.isEmpty { return false }

        if PreviewTypeClassifier.isSpreadsheetFile(ext),
           session.office.spreadsheetMode == .text,
           !session.content.textContent.isEmpty {
            return false
        }

        if PreviewTypeClassifier.isWordDocumentFile(ext),
           session.office.wordDocumentMode == .text,
           !session.content.textContent.isEmpty {
            return false
        }

        if PreviewTypeClassifier.isWordDocumentFile(ext),
           session.office.wordDocumentMode == .formatted,
           session.content.officeRichText != nil {
            return false
        }

        if session.content.officeURL != nil,
           !(PreviewTypeClassifier.isSpreadsheetFile(ext) && session.office.spreadsheetMode == .text),
           !(PreviewTypeClassifier.isWordDocumentFile(ext) && session.office.wordDocumentMode == .text) {
            return false
        }

        if PreviewTypeClassifier.isHtmlFile(ext), session.text.htmlMode == .preview {
            return false
        }

        if PreviewTypeClassifier.isMarkdownFile(ext), session.text.markdownMode == .preview {
            return false
        }

        return showsTextPreviewContent(file: file, session: session)
    }
}
