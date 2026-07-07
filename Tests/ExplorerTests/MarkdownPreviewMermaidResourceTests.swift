import XCTest
@testable import Explorer

final class MarkdownPreviewMermaidResourceTests: XCTestCase {
    func testMermaidScriptIsBundled() {
        XCTAssertNotNil(Bundle.module.url(forResource: "mermaid", withExtension: "min.js"))
        XCTAssertNotNil(Bundle.module.url(forResource: "mermaid-preview-shell", withExtension: "html"))
    }
}
