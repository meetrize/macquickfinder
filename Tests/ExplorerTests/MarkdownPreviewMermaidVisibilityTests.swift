import XCTest
@testable import Explorer

final class MarkdownPreviewMermaidVisibilityTests: XCTestCase {
    func testRectsIntersectWhenAttachmentInsideVisibleArea() {
        let attachment = CGRect(x: 40, y: 200, width: 400, height: 180)
        let visible = CGRect(x: 0, y: 0, width: 800, height: 600)
        XCTAssertTrue(MarkdownPreviewMermaidVisibility.rectsIntersect(attachment, visible: visible))
    }

    func testRectsIntersectWithPreloadMarginCoversNearbyAttachment() {
        let attachment = CGRect(x: 0, y: 900, width: 400, height: 120)
        let visible = CGRect(x: 0, y: 0, width: 800, height: 600)
        let expanded = visible.insetBy(dx: 0, dy: -MarkdownPreviewMermaidVisibility.preloadMargin)
        XCTAssertTrue(MarkdownPreviewMermaidVisibility.rectsIntersect(attachment, visible: expanded))
    }

    func testRectsDoNotIntersectWhenFarBelowVisibleArea() {
        let attachment = CGRect(x: 0, y: 2_000, width: 400, height: 120)
        let visible = CGRect(x: 0, y: 0, width: 800, height: 600)
        let expanded = visible.insetBy(dx: 0, dy: -MarkdownPreviewMermaidVisibility.preloadMargin)
        XCTAssertFalse(MarkdownPreviewMermaidVisibility.rectsIntersect(attachment, visible: expanded))
    }
}
