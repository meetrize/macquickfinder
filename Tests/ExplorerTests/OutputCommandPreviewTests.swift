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

    func testResolvedExpandedEditorHeightNeverExceedsPanelBudget() {
        let command = String(repeating: "echo hello\n", count: 20)
        let panelHeight: CGFloat = 180
        let resolved = OutputCommandPreview.resolvedExpandedEditorHeight(
            for: command,
            panelHeight: panelHeight,
            hasCompletionHint: false
        )
        let maxAllowed = OutputCommandPreview.maxExpandedEditorHeight(
            panelHeight: panelHeight,
            hasCompletionHint: false
        )
        XCTAssertLessThanOrEqual(resolved, maxAllowed)
        XCTAssertLessThanOrEqual(
            resolved + OutputCommandPreview.minimumPanelHeight(
                forExpandedEditorHeight: resolved,
                hasCompletionHint: false
            ),
            panelHeight + 1
        )
    }

    func testMinimumPanelHeightIncludesExpandedEditor() {
        let editorHeight: CGFloat = 120
        let minimum = OutputCommandPreview.minimumPanelHeight(
            forExpandedEditorHeight: editorHeight,
            hasCompletionHint: true
        )
        XCTAssertGreaterThanOrEqual(minimum, editorHeight + OutputPanelMetrics.titleBarHeight)
    }
}
