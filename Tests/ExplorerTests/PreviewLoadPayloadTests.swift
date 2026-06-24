import Foundation
import XCTest
@testable import Explorer

@MainActor
final class PreviewLoadPayloadTests: XCTestCase {
    private func makeSession() -> PreviewSession {
        PreviewSession(
            hostWindowID: UUID(),
            file: FileItem(
                id: "file-a",
                url: URL(fileURLWithPath: "/tmp/file-a.txt"),
                name: "file-a.txt",
                isDirectory: false,
                modificationDate: .distantPast,
                size: 0,
                isHidden: false,
                fileType: "txt",
                sizeDisplay: "0 B",
                dateDisplay: ""
            )
        )
    }

    func testApplyUnavailableClearsBinaryContentAndMarksLoaded() {
        let session = makeSession()
        session.content.textContent = "stale"
        session.content.archiveEntries = [
            ArchiveEntryPreview(path: "a.txt", isDirectory: false, size: 1)
        ]

        XCTAssertTrue(session.applyLoadPayload(.unavailable, expectedItemID: "file-a"))

        XCTAssertNil(session.content.image)
        XCTAssertNil(session.content.pdfDocument)
        XCTAssertNil(session.content.mediaPlayer)
        XCTAssertTrue(session.content.archiveEntries.isEmpty)
        XCTAssertEqual(session.content.textContent, "stale")
        if case .loaded = session.content.loadPhase {
            // expected
        } else {
            XCTFail("Expected loaded phase")
        }
    }

    func testApplyFailureSetsErrorPhase() {
        let session = makeSession()
        XCTAssertTrue(session.applyLoadPayload(.failure("boom"), expectedItemID: "file-a"))
        if case .failed("boom") = session.content.loadPhase {
            // expected
        } else {
            XCTFail("Expected failed phase")
        }
    }

    func testApplyRejectsStaleItemID() {
        let session = makeSession()
        XCTAssertFalse(session.applyLoadPayload(.text("hello"), expectedItemID: "other-id"))
        XCTAssertTrue(session.content.textContent.isEmpty)
    }
}
