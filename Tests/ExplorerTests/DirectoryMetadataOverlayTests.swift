import XCTest
@testable import Explorer
import FileList

@MainActor
final class DirectoryMetadataOverlayTests: XCTestCase {
    func testBeginSessionResetsSizeAndCount() {
        let overlay = DirectoryMetadataOverlay.shared
        overlay.beginSession(generation: 1)
        overlay.apply(path: "/tmp/a", result: .complete(100), generation: 1)
        overlay.apply(path: "/tmp/b", count: 3, generation: 1)

        overlay.beginSession(generation: 2)

        XCTAssertEqual(overlay.sizeDisplay(for: "/tmp/a"), .unknown)
        XCTAssertEqual(overlay.countDisplay(for: "/tmp/b"), .unknown)
        XCTAssertEqual(overlay.sizeRevision, 0)
        XCTAssertEqual(overlay.countRevision, 0)
    }

    func testBeginSizeSessionPreservesCounts() {
        let overlay = DirectoryMetadataOverlay.shared
        overlay.beginSession(generation: 10)
        overlay.apply(path: "/tmp/dir", result: .complete(200), generation: 10)
        overlay.apply(path: "/tmp/dir", count: 5, generation: 10)

        overlay.beginSizeSession(generation: 11)
        overlay.apply(path: "/tmp/dir", count: 7, generation: 10)

        XCTAssertEqual(overlay.sizeDisplay(for: "/tmp/dir"), .unknown)
        XCTAssertEqual(overlay.countDisplay(for: "/tmp/dir").count, 5)
    }

    func testSizeDisplayFormatsLowerBound() {
        let overlay = DirectoryMetadataOverlay.shared
        overlay.beginSession(generation: 20)
        overlay.apply(path: "/tmp/lb", result: .lowerBound(1024), generation: 20)

        let display = overlay.sizeDisplay(for: "/tmp/lb")
        XCTAssertEqual(display.sortableSize, 1024)
        XCTAssertTrue(display.text.hasPrefix("≥"))
    }

    func testRemoveSizesDoesNotClearCounts() {
        let overlay = DirectoryMetadataOverlay.shared
        overlay.beginSession(generation: 30)
        overlay.apply(path: "/tmp/x", result: .complete(50), generation: 30)
        overlay.apply(path: "/tmp/x", count: 2, generation: 30)

        overlay.removeSizes(paths: ["/tmp/x"])

        XCTAssertEqual(overlay.sizeDisplay(for: "/tmp/x"), .unknown)
        XCTAssertEqual(overlay.countDisplay(for: "/tmp/x").count, 2)
    }

    func testStaleGenerationApplyIsIgnored() {
        let overlay = DirectoryMetadataOverlay.shared
        overlay.beginSession(generation: 40)
        overlay.apply(path: "/tmp/stale", result: .complete(99), generation: 39)

        XCTAssertEqual(overlay.sizeDisplay(for: "/tmp/stale"), .unknown)
    }
}
