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

        XCTAssertEqual(session.imageZoomScale, 1.0)
        XCTAssertNil(session.imageZoomAction)
        XCTAssertEqual(session.imageEffectiveZoomPercent, 0)
        XCTAssertEqual(session.pdfCurrentPage, 0)
        XCTAssertTrue(session.textWrapEnabled)
        XCTAssertEqual(session.markdownMode, .preview)
        XCTAssertEqual(session.htmlMode, .preview)
        XCTAssertEqual(session.location, .inline)
        XCTAssertNil(session.folderInlineChild)
    }

    func testResetControlsClearsMutatedState() {
        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem())
        session.imageZoomScale = 2.5
        session.imageRotationQuarterTurns = 1
        session.pdfCurrentPage = 3
        session.markdownMode = .source
        session.mediaIsPlaying = true
        session.archiveExpanded = false
        session.imageEditUndoStack = [
            ImageEditSnapshot(
                rotationQuarterTurns: 0,
                flipHorizontal: false,
                flipVertical: false,
                resizeTargetSize: nil,
                zoomScale: 1.0
            ),
        ]

        session.resetControls()

        XCTAssertEqual(session.imageZoomScale, 1.0)
        XCTAssertEqual(session.imageRotationQuarterTurns, 0)
        XCTAssertEqual(session.pdfCurrentPage, 0)
        XCTAssertEqual(session.markdownMode, .preview)
        XCTAssertFalse(session.mediaIsPlaying)
        XCTAssertTrue(session.archiveExpanded)
        XCTAssertTrue(session.imageEditUndoStack.isEmpty)
    }

    func testImageEditUndoRoundTrip() {
        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem())
        session.imageZoomScale = 1.0

        session.performImageEdit {
            session.imageZoomScale = 2.0
            session.imageRotationQuarterTurns = 1
        }
        XCTAssertEqual(session.imageZoomScale, 2.0)
        XCTAssertEqual(session.imageRotationQuarterTurns, 1)

        session.undoLastImageEdit()
        XCTAssertEqual(session.imageZoomScale, 1.0)
        XCTAssertEqual(session.imageRotationQuarterTurns, 0)
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
        session.imageSourcePixelSize = CGSize(width: 800, height: 600)
        session.imageRotationQuarterTurns = 1

        let oriented = session.imageEffectiveOrientedPixelSize
        XCTAssertEqual(oriented.width, 600)
        XCTAssertEqual(oriented.height, 800)
    }
}
