import AppKit
import Foundation

enum PreviewContentLoader {
    static func loadMappedData(from url: URL) async -> Data? {
        try? await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: url, options: [.mappedIfSafe])
        }.value
    }

    static func loadText(from url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try TextFilePreviewReader.readPreview(from: url)
        }.value
    }

    static func loadDOCXRichText(from url: URL) async -> NSAttributedString? {
        await loadOfficeRichText {
            try OfficeDocumentPreviewLoader.loadDOCXRTFData(from: url)
        }
    }

    static func loadDOCRichText(from url: URL) async -> NSAttributedString? {
        await loadOfficeRichText {
            try OfficeDocumentPreviewLoader.loadDOCRTFData(from: url)
        }
    }

    static func loadRTFRichText(from url: URL) async -> NSAttributedString? {
        await loadOfficeRichText {
            try Data(contentsOf: url, options: [.mappedIfSafe])
        }
    }

    static func loadEpub(from url: URL) async -> Result<EpubPreviewPackage, Error> {
        await Task.detached(priority: .userInitiated) {
            Result { try EpubPreviewLoader.load(from: url) }
        }.value
    }

    static func loadEml(from url: URL) async -> Result<EmlPreviewContent, Error> {
        await Task.detached(priority: .userInitiated) {
            Result { try EmlPreviewLoader.load(from: url) }
        }.value
    }

    static func loadFont(from url: URL) async -> Result<FontPreviewContent, Error> {
        await Task.detached(priority: .userInitiated) {
            Result { try FontPreviewLoader.load(from: url) }
        }.value
    }

    static func loadSpreadsheetText(from url: URL) async -> String? {
        try? await Task.detached(priority: .userInitiated) {
            try SpreadsheetPreviewLoader.loadText(from: url)
        }.value
    }

    private static func loadOfficeRichText(rtfDataProvider: @escaping () throws -> Data) async -> NSAttributedString? {
        let rtfData = try? await Task.detached(priority: .userInitiated) {
            try rtfDataProvider()
        }.value
        guard let rtfData,
              let richText = NSAttributedString(rtf: rtfData, documentAttributes: nil),
              richText.length > 0 else {
            return nil
        }
        return richText
    }

    static func loadArchive(
        at url: URL,
        detail: ArchiveListingDetail = .summary,
        maxEntries: Int? = nil,
        timeoutSeconds: Int = 8
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        try await ArchivePreviewLoader.listArchiveEntries(
            at: url,
            detail: detail,
            maxEntries: maxEntries,
            timeoutSeconds: timeoutSeconds
        )
    }
}
