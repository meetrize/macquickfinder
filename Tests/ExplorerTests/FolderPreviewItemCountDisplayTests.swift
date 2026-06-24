import XCTest
@testable import Explorer

final class FolderPreviewItemCountDisplayTests: XCTestCase {
    @MainActor
    func testResolvedCountUsesOverlayOnly() {
        let overlay = DirectoryMetadataOverlay.shared
        overlay.beginSession(generation: 1)
        overlay.apply(path: "/tmp/preview-count", count: 12, generation: 1)

        XCTAssertEqual(
            FolderPreviewItemCountDisplay.resolvedCount(from: overlay, path: "/tmp/preview-count"),
            12
        )
        XCTAssertNil(
            FolderPreviewItemCountDisplay.resolvedCount(from: overlay, path: "/tmp/missing")
        )
    }

    @MainActor
    func testSummaryTextForApplicationBundle() {
        XCTAssertEqual(
            FolderPreviewItemCountDisplay.summaryText(count: nil, isApplicationBundle: true),
            "— 项"
        )
    }

    @MainActor
    func testSummaryTextShowsLoadingWhenCountUnknown() {
        XCTAssertEqual(
            FolderPreviewItemCountDisplay.summaryText(count: nil, isApplicationBundle: false),
            "正在统计…"
        )
        XCTAssertEqual(
            FolderPreviewItemCountDisplay.summaryText(count: 5, isApplicationBundle: false),
            "5 项"
        )
    }

    func testTruncationCaptionWithoutTotal() {
        XCTAssertEqual(
            FolderPreviewItemCountDisplay.truncationCaption(maxChildren: 200, totalCount: nil),
            "显示前 200 项"
        )
        XCTAssertEqual(
            FolderPreviewItemCountDisplay.truncationCaption(maxChildren: 200, totalCount: 480),
            "显示前 200 / 480 项"
        )
    }
}
