import XCTest
@testable import Explorer

final class OutputCommandPreviewTests: XCTestCase {
    func testNeedsCollapseForMultiline() {
        XCTAssertTrue(OutputCommandPreview.needsCollapse("line1\nline2"))
    }

    func testNeedsCollapseForLongSingleLine() {
        let long = String(repeating: "a", count: 100)
        XCTAssertTrue(OutputCommandPreview.needsCollapse(long))
    }

    func testDoesNotCollapseShortSingleLine() {
        XCTAssertFalse(OutputCommandPreview.needsCollapse("ls -la"))
    }

    func testCollapsedLineReplacesNewlines() {
        let result = OutputCommandPreview.collapsedLine("a\nb")
        XCTAssertTrue(result.contains("↵"))
    }

    func testExpandCommandL10nNotRawKey() {
        XCTAssertNotEqual(L10n.Snippets.Output.expandCommand, "snippets.output.expand_command")
        XCTAssertNotEqual(L10n.Snippets.Output.fullCommandTitle, "snippets.output.full_command_title")
    }
}
