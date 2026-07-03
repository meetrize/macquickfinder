import XCTest
@testable import Explorer

@MainActor
final class PreviewTextEditEligibilityTests: XCTestCase {
    private func makeFileItem(
        id: String = "file-a",
        name: String = "file-a.txt",
        ext: String = "txt"
    ) -> FileItem {
        let fileName = ext.isEmpty ? name : "sample.\(ext)"
        return FileItem(
            id: id,
            url: URL(fileURLWithPath: "/tmp/\(fileName)"),
            name: fileName,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 100,
            isHidden: false,
            fileType: ext,
            sizeDisplay: "100 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    private func makeSession(file: FileItem) -> PreviewSession {
        PreviewSession(hostWindowID: UUID(), file: file)
    }

    func testCanEditPlainTextWhenLoadedAndWritable() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewTextEditEligibility-\(UUID().uuidString).txt")
        try Data("hello".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let file = FileItem(
            id: "txt-file",
            url: fileURL,
            name: fileURL.lastPathComponent,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 5,
            isHidden: false,
            fileType: "txt",
            sizeDisplay: "5 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let session = makeSession(file: file)
        session.content.textContent = "hello"
        session.content.loadPhase = .loaded

        XCTAssertTrue(PreviewTextEditEligibility.canEdit(file: file, session: session))
    }

    func testRejectsTruncatedContent() {
        let file = makeFileItem(ext: "swift")
        let session = makeSession(file: file)
        session.content.textContent = "code\(TextFilePreviewReader.truncationMarker)"
        session.content.loadPhase = .loaded

        XCTAssertEqual(
            PreviewTextEditEligibility.denialReason(for: file, session: session),
            .contentTruncated
        )
    }

    func testRejectsMarkdownPreviewModeForDirectEdit() {
        let file = makeFileItem(ext: "md")
        let session = makeSession(file: file)
        session.content.textContent = "# Title"
        session.content.loadPhase = .loaded
        session.text.markdownMode = .preview

        XCTAssertEqual(
            PreviewTextEditEligibility.denialReason(for: file, session: session),
            .notUsingTextFilePreview
        )
    }

    func testOffersEditForMarkdownPreviewMode() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewTextEditEligibility-\(UUID().uuidString).md")
        try Data("# Title".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let file = FileItem(
            id: "md-file",
            url: fileURL,
            name: fileURL.lastPathComponent,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 7,
            isHidden: false,
            fileType: "md",
            sizeDisplay: "7 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let session = makeSession(file: file)
        session.content.textContent = "# Title"
        session.content.loadPhase = .loaded
        session.text.markdownMode = .preview

        XCTAssertTrue(PreviewTextEditEligibility.canOfferEdit(file: file, session: session))
        XCTAssertFalse(PreviewTextEditEligibility.canEdit(file: file, session: session))
    }

    func testAllowsMarkdownSourceMode() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewTextEditEligibility-\(UUID().uuidString).md")
        try Data("# Title".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let file = FileItem(
            id: "md-file",
            url: fileURL,
            name: fileURL.lastPathComponent,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 7,
            isHidden: false,
            fileType: "md",
            sizeDisplay: "7 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let session = makeSession(file: file)
        session.content.textContent = "# Title"
        session.content.loadPhase = .loaded
        session.text.markdownMode = .source

        XCTAssertTrue(PreviewTextEditEligibility.canEdit(file: file, session: session))
    }

    func testRejectsHtmlPreviewMode() {
        let file = makeFileItem(ext: "html")
        let session = makeSession(file: file)
        session.content.textContent = "<p>hi</p>"
        session.content.loadPhase = .loaded
        session.text.htmlMode = .preview

        XCTAssertEqual(
            PreviewTextEditEligibility.denialReason(for: file, session: session),
            .notUsingTextFilePreview
        )
    }

    func testRejectsSpreadsheetTextMode() {
        let file = makeFileItem(ext: "csv")
        let session = makeSession(file: file)
        session.content.textContent = "a,b"
        session.content.loadPhase = .loaded
        session.office.spreadsheetMode = .text

        XCTAssertEqual(
            PreviewTextEditEligibility.denialReason(for: file, session: session),
            .notUsingTextFilePreview
        )
    }

    func testRejectsNonTextExtension() {
        let file = makeFileItem(ext: "png")
        let session = makeSession(file: file)
        session.content.textContent = "not really text preview"
        session.content.loadPhase = .loaded

        XCTAssertEqual(
            PreviewTextEditEligibility.denialReason(for: file, session: session),
            .notTextFile
        )
    }

    func testIsContentTruncatedUsesSharedMarker() {
        XCTAssertTrue(PreviewTextEditEligibility.isContentTruncated("x\(TextFilePreviewReader.truncationMarker)"))
        XCTAssertFalse(PreviewTextEditEligibility.isContentTruncated("plain text"))
    }
}
