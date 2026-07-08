import XCTest
@testable import Explorer

final class MarkdownPreviewMermaidFittingTests: XCTestCase {
    func testScalesUpSmallDiagramToFillWidth() {
        let viewport = MarkdownPreviewMermaidFitting.Viewport(maxWidth: 400, maxHeight: 300)
        let size = MarkdownPreviewMermaidFitting.displaySize(
            naturalSize: NSSize(width: 100, height: 50),
            viewport: viewport
        )
        XCTAssertEqual(size.width, 400)
        XCTAssertEqual(size.height, 200)
    }

    func testScalesDownTallDiagramToFitHeight() {
        let viewport = MarkdownPreviewMermaidFitting.Viewport(maxWidth: 400, maxHeight: 300)
        let size = MarkdownPreviewMermaidFitting.displaySize(
            naturalSize: NSSize(width: 200, height: 800),
            viewport: viewport
        )
        XCTAssertEqual(size.width, 75)
        XCTAssertEqual(size.height, 300)
    }

    func testPreservesAspectRatioWithinViewport() {
        let viewport = MarkdownPreviewMermaidFitting.Viewport(maxWidth: 500, maxHeight: 400)
        let size = MarkdownPreviewMermaidFitting.displaySize(
            naturalSize: NSSize(width: 1000, height: 500),
            viewport: viewport
        )
        XCTAssertEqual(size.width, 500)
        XCTAssertEqual(size.height, 250)
    }
}
