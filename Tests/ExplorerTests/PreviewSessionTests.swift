import AppKit
import CoreGraphics
import PDFKit
import XCTest
@testable import Explorer

@MainActor
final class PreviewSessionTests: XCTestCase {
    private func makeFileItem(id: String = "file-a") -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: "/tmp/\(id).txt"),
            name: "\(id).txt",
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "txt",
            sizeDisplay: "0 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func testDefaultToolbarStateMatchesFilePreviewView() {
        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem())

        XCTAssertEqual(session.image.zoomScale, 1.0)
        XCTAssertNil(session.image.zoomAction)
        XCTAssertEqual(session.image.effectiveZoomPercent, 0)
        XCTAssertEqual(session.pdf.currentPage, 0)
        XCTAssertFalse(session.text.wrapEnabled)
        XCTAssertEqual(session.text.markdownMode, .preview)
        XCTAssertEqual(session.text.htmlMode, .preview)
        XCTAssertEqual(session.location, .inline)
        XCTAssertNil(session.folderInlineChild)
    }

    func testResetControlsClearsMutatedState() {
        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem())
        session.image.zoomScale = 2.5
        session.image.rotationQuarterTurns = 1
        session.pdf.currentPage = 3
        session.text.markdownMode = .source
        session.media.isPlaying = true
        session.archive.expandedDirectoryPaths = ["docs"]
        session.office.zoomScale = 1.5
        session.office.currentPage = 2
        session.office.pageCount = 5
        session.image.editUndoStack = [
            ImageEditSnapshot(
                rotationQuarterTurns: 0,
                flipHorizontal: false,
                flipVertical: false,
                resizeTargetSize: nil,
                zoomScale: 1.0
            ),
        ]

        session.resetControls()

        XCTAssertEqual(session.image.zoomScale, 1.0)
        XCTAssertEqual(session.image.rotationQuarterTurns, 0)
        XCTAssertEqual(session.pdf.currentPage, 0)
        XCTAssertEqual(session.text.markdownMode, .preview)
        XCTAssertFalse(session.media.isPlaying)
        XCTAssertTrue(session.archive.expandedDirectoryPaths.isEmpty)
        XCTAssertEqual(session.office.zoomScale, 1.0)
        XCTAssertEqual(session.office.currentPage, 0)
        XCTAssertEqual(session.office.pageCount, 0)
        XCTAssertTrue(session.image.editUndoStack.isEmpty)
    }

    func testOfficeToolbarIncludesZoomControlsInFormattedMode() {
        let session = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "doc",
                url: URL(fileURLWithPath: "/tmp/sample.docx"),
                name: "sample.docx",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 1024,
                isHidden: false,
                fileType: "docx",
                sizeDisplay: "1 KB",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )
        session.content.textContent = "Hello"
        session.content.officeRichText = NSAttributedString(string: "Hello")
        session.office.wordDocumentMode = WordDocumentDisplayMode.formatted
        let items = session.previewToolbarItems(for: session.file)
        let ids = Set(items.map(\.id))
        XCTAssertTrue(ids.contains("word-document-toggle-mode"))
        XCTAssertTrue(ids.contains("office-zoom-out"))
        XCTAssertTrue(ids.contains("office-scale"))
        XCTAssertTrue(ids.contains("office-zoom-in"))
        XCTAssertTrue(ids.contains("office-reset"))
        XCTAssertFalse(ids.contains("office-pan"))
        XCTAssertFalse(ids.contains("office-prev"))
        XCTAssertFalse(ids.contains("office-next"))
    }

    func testWordDocumentTextModeToolbarIncludesPlainTextControls() {
        let session = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "doc",
                url: URL(fileURLWithPath: "/tmp/sample.doc"),
                name: "sample.doc",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 1024,
                isHidden: false,
                fileType: "doc",
                sizeDisplay: "1 KB",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )
        session.content.textContent = "Hello"
        session.content.officeRichText = NSAttributedString(string: "Hello")
        session.office.wordDocumentMode = WordDocumentDisplayMode.text
        let items = session.previewToolbarItems(for: session.file)
        let ids = Set(items.map(\.id))
        XCTAssertTrue(ids.contains("word-document-toggle-mode"))
        XCTAssertTrue(ids.contains("word-document-wrap"))
        XCTAssertTrue(ids.contains("word-document-copy"))
        XCTAssertFalse(ids.contains("office-zoom-in"))
    }

    func testShowsPreviewTextSearchForSupportedTypes() {
        let pdfSession = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "pdf",
                url: URL(fileURLWithPath: "/tmp/sample.pdf"),
                name: "sample.pdf",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 1024,
                isHidden: false,
                fileType: "pdf",
                sizeDisplay: "1 KB",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )
        XCTAssertFalse(pdfSession.showsPreviewTextSearch(for: pdfSession.file))
        pdfSession.content.pdfDocument = PDFDocument()
        XCTAssertTrue(pdfSession.showsPreviewTextSearch(for: pdfSession.file))

        let mdSession = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "md",
                url: URL(fileURLWithPath: "/tmp/readme.md"),
                name: "readme.md",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 128,
                isHidden: false,
                fileType: "md",
                sizeDisplay: "128 B",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )
        mdSession.content.textContent = "# Title"
        XCTAssertTrue(mdSession.showsPreviewTextSearch(for: mdSession.file))

        let xlsxSession = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "xlsx",
                url: URL(fileURLWithPath: "/tmp/data.xlsx"),
                name: "data.xlsx",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 1024,
                isHidden: false,
                fileType: "xlsx",
                sizeDisplay: "1 KB",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )
        xlsxSession.content.textContent = "A\tB"
        xlsxSession.office.spreadsheetMode = .text
        XCTAssertTrue(xlsxSession.showsPreviewTextSearch(for: xlsxSession.file))
        xlsxSession.office.spreadsheetMode = .quickLook
        XCTAssertFalse(xlsxSession.showsPreviewTextSearch(for: xlsxSession.file))

        let csvSession = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "csv",
                url: URL(fileURLWithPath: "/tmp/data.csv"),
                name: "data.csv",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 256,
                isHidden: false,
                fileType: "csv",
                sizeDisplay: "256 B",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )
        csvSession.content.textContent = "a,b\n1,2"
        csvSession.content.officeURL = URL(fileURLWithPath: "/tmp/data.csv")
        let csvToolbarIDs = Set(csvSession.previewToolbarItems(for: csvSession.file).map(\.id))
        XCTAssertTrue(csvToolbarIDs.contains("spreadsheet-toggle-mode"))
        csvSession.office.spreadsheetMode = .text
        XCTAssertTrue(csvSession.showsPreviewTextSearch(for: csvSession.file))
        csvSession.office.spreadsheetMode = .quickLook
        XCTAssertFalse(csvSession.showsPreviewTextSearch(for: csvSession.file))

        let docxSession = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "docx",
                url: URL(fileURLWithPath: "/tmp/readme.docx"),
                name: "readme.docx",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 128,
                isHidden: false,
                fileType: "docx",
                sizeDisplay: "128 B",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )
        docxSession.content.textContent = "Body"
        docxSession.content.officeRichText = NSAttributedString(string: "Body")
        docxSession.office.wordDocumentMode = WordDocumentDisplayMode.text
        XCTAssertTrue(docxSession.showsPreviewTextSearch(for: docxSession.file))
        docxSession.office.wordDocumentMode = WordDocumentDisplayMode.formatted
        XCTAssertTrue(docxSession.showsPreviewTextSearch(for: docxSession.file))
    }

    func testQuickLookOfficeToolbarIncludesPageControlsWhenMultiplePages() {
        let session = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "deck",
                url: URL(fileURLWithPath: "/tmp/sample.pptx"),
                name: "sample.pptx",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 1024,
                isHidden: false,
                fileType: "pptx",
                sizeDisplay: "1 KB",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )
        session.content.officeURL = URL(fileURLWithPath: "/tmp/sample.pptx")
        session.office.pageCount = 3
        session.office.currentPage = 2

        let items = session.previewToolbarItems(for: session.file)
        let ids = Set(items.map(\.id))
        XCTAssertTrue(ids.contains("office-prev"))
        XCTAssertTrue(ids.contains("office-next"))
        XCTAssertTrue(ids.contains("office-page"))
        XCTAssertTrue(ids.contains("office-zoom-in"))
    }

    func testRunnableScriptToolbarIncludesRunButton() {
        let session = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "script",
                url: URL(fileURLWithPath: "/tmp/sample.py"),
                name: "sample.py",
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 128,
                isHidden: false,
                fileType: "py",
                sizeDisplay: "128 B",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
        )

        let items = session.previewToolbarItems(for: session.file)
        XCTAssertEqual(items.first?.id, "script-run")
    }

    func testImageEditUndoRoundTrip() {
        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem())
        session.image.zoomScale = 1.0

        session.image.performEdit {
            session.image.zoomScale = 2.0
            session.image.rotationQuarterTurns = 1
        }
        XCTAssertEqual(session.image.zoomScale, 2.0)
        XCTAssertEqual(session.image.rotationQuarterTurns, 1)

        session.image.undoLastEdit()
        XCTAssertEqual(session.image.zoomScale, 1.0)
        XCTAssertEqual(session.image.rotationQuarterTurns, 0)
    }

    func testPreviewContentItemPrefersFolderInlineChild() {
        let parent = makeFileItem(id: "folder")
        let child = makeFileItem(id: "child.png")
        let session = PreviewSession(
            hostWindowID: UUID(),
            file: parent,
            folderInlineChild: child
        )

        XCTAssertEqual(session.previewContentItem?.id, child.id)
        XCTAssertTrue(session.isShowingFolderChildPreview)
        XCTAssertEqual(session.toolbarFileItem?.id, child.id)
    }

    func testImageEffectiveOrientedPixelSizeSwapsOn90DegreeRotation() {
        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem())
        session.image.sourcePixelSize = CGSize(width: 800, height: 600)
        session.image.rotationQuarterTurns = 1

        let oriented = session.image.effectiveOrientedPixelSize
        XCTAssertEqual(oriented.width, 600)
        XCTAssertEqual(oriented.height, 800)
    }
}
