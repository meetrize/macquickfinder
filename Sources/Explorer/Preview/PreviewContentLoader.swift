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
        let rtfData = try? await Task.detached(priority: .userInitiated) {
            try OfficeDocumentPreviewLoader.loadDOCXRTFData(from: url)
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
        maxEntries: Int = 1_000,
        timeoutSeconds: Int = 8
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        try await ArchivePreviewLoader.listArchiveEntries(
            at: url,
            maxEntries: maxEntries,
            timeoutSeconds: timeoutSeconds
        )
    }
}
