import CoreGraphics
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
            size: 0,
            isHidden: false,
            fileType: "txt",
            sizeDisplay: "0 B",
            dateDisplay: ""
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
        session.archive.expanded = false
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
        XCTAssertTrue(session.archive.expanded)
        XCTAssertEqual(session.office.zoomScale, 1.0)
        XCTAssertEqual(session.office.currentPage, 0)
        XCTAssertEqual(session.office.pageCount, 0)
        XCTAssertTrue(session.image.editUndoStack.isEmpty)
    }

    func testOfficeToolbarIncludesZoomControls() {
        let session = PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "doc",
                url: URL(fileURLWithPath: "/tmp/sample.docx"),
                name: "sample.docx",
                isDirectory: false,
                modificationDate: .distantPast,
                size: 1024,
                isHidden: false,
                fileType: "docx",
                sizeDisplay: "1 KB",
                dateDisplay: ""
            )
        )
        let items = session.previewToolbarItems(for: session.file)
        let ids = Set(items.map(\.id))
        XCTAssertTrue(ids.contains("office-zoom-out"))
        XCTAssertTrue(ids.contains("office-scale"))
        XCTAssertTrue(ids.contains("office-zoom-in"))
        XCTAssertTrue(ids.contains("office-reset"))
        XCTAssertFalse(ids.contains("office-pan"))
        XCTAssertFalse(ids.contains("office-prev"))
        XCTAssertFalse(ids.contains("office-next"))
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
                size: 1024,
                isHidden: false,
                fileType: "pptx",
                sizeDisplay: "1 KB",
                dateDisplay: ""
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
