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
        XCTAssertNil(
            FolderPreviewItemCountDisplay.resolvedCount(
                from: overlay,
                path: "/Applications/Safari.app"
            )
        )
    }

    @MainActor
    func testSummaryTextForApplicationBundle() {
        let text = FolderPreviewItemCountDisplay.summaryText(count: nil, isApplicationBundle: true)
        XCTAssertEqual(text, L10n.Preview.Folder.applicationKind)
        XCTAssertNotEqual(text, "preview.folder.application_kind")
    }

    @MainActor
    func testSummaryTextShowsLoadingWhenCountUnknown() {
        let loading = FolderPreviewItemCountDisplay.summaryText(count: nil, isApplicationBundle: false)
        XCTAssertEqual(loading, L10n.Preview.Folder.countingItems)
        XCTAssertNotEqual(loading, "preview.folder.counting_items")

        let counted = FolderPreviewItemCountDisplay.summaryText(count: 5, isApplicationBundle: false)
        XCTAssertEqual(counted, L10n.Preview.Folder.itemCount(5))
        XCTAssertFalse(counted.contains("preview.folder.item_count"))
    }

    @MainActor
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
