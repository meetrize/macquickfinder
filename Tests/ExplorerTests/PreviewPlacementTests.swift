import XCTest
@testable import Explorer

final class PreviewPlacementTests: XCTestCase {
    func testInlineShowsNoPlaceholder() {
        let placement = PreviewPlacement.inline
        XCTAssertFalse(placement.showsPlaceholder(forSelectedFileID: "file-a"))
        XCTAssertFalse(placement.isDetached)
    }

    func testDetachedPlaceholderOnlyForMatchingFile() {
        let sessionID = PreviewSessionID()
        let placement = PreviewPlacement.detached(sessionID: sessionID, fileID: "file-a")

        XCTAssertTrue(placement.isDetached)
        XCTAssertTrue(placement.showsPlaceholder(forSelectedFileID: "file-a"))
        XCTAssertFalse(placement.showsPlaceholder(forSelectedFileID: "file-b"))
        XCTAssertFalse(placement.showsPlaceholder(forSelectedFileID: nil))
    }

    func testDetachedSessionIDLookup() {
        let sessionID = PreviewSessionID()
        let placement = PreviewPlacement.detached(sessionID: sessionID, fileID: "file-a")

        XCTAssertEqual(placement.detachedSessionID(forFileID: "file-a"), sessionID)
        XCTAssertNil(placement.detachedSessionID(forFileID: "file-b"))
    }

    func testPreviewWindowValueCodableRoundTrip() throws {
        let value = PreviewWindowValue(sessionID: PreviewSessionID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(PreviewWindowValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }
}
