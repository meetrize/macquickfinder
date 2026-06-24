import XCTest
@testable import Explorer

final class RightPanelHeightCalculatorTests: XCTestCase {
    private let total: CGFloat = 800
    private let titleBar: CGFloat = PanelTopBarMetrics.totalHeight
    private let divider: CGFloat = VerticalResizeDividerMetrics.hitHeight

    private func baseInput(
        showPreview: Bool = true,
        showSnippets: Bool = true,
        previewCollapsed: Bool = false,
        snippetsCollapsed: Bool = false,
        ratio: Double = 0.55,
        dragHeight: CGFloat? = nil
    ) -> RightPanelHeightCalculator.Input {
        RightPanelHeightCalculator.Input(
            totalHeight: total,
            showPreview: showPreview,
            showSnippets: showSnippets,
            isPreviewContentCollapsed: previewCollapsed,
            isSnippetsContentCollapsed: snippetsCollapsed,
            previewSnippetsSplitRatio: ratio,
            dragPreviewHeight: dragHeight,
            dividerHeight: divider,
            previewMinHeight: 80,
            snippetsMinHeight: 80,
            collapsedTitleBarHeight: titleBar
        )
    }

    func testPreviewOnlyFillsEntirePanel() {
        let input = baseInput(showSnippets: false, ratio: 0.55)
        XCTAssertEqual(RightPanelHeightCalculator.previewHeight(for: input), total)
    }

    func testSnippetsOnlyDoesNotAllocatePreviewHeight() {
        let input = baseInput(showPreview: false, showSnippets: true)
        XCTAssertEqual(RightPanelHeightCalculator.previewHeight(for: input), 0)
    }

    func testBothExpandedUsesSplitRatio() {
        let input = baseInput(ratio: 0.55)
        let expected = RightPanelHeightCalculator.clampedSplitPreviewHeight(for: input)
        XCTAssertEqual(RightPanelHeightCalculator.previewHeight(for: input), expected)
        XCTAssertEqual(expected, total * 0.55, accuracy: 0.01)
    }

    func testClosingOnePanelRestoresFullHeightForPreview() {
        var input = baseInput(ratio: 0.4)
        XCTAssertEqual(RightPanelHeightCalculator.previewHeight(for: input), total * 0.4, accuracy: 0.01)

        input.showSnippets = false
        XCTAssertEqual(RightPanelHeightCalculator.previewHeight(for: input), total)
    }

    func testSnippetsCollapsedPreviewExpands() {
        let input = baseInput(snippetsCollapsed: true)
        XCTAssertEqual(
            RightPanelHeightCalculator.previewHeight(for: input),
            total - input.snippetsMinHeight
        )
    }

    func testPreviewCollapsedUsesTitleBarHeight() {
        let input = baseInput(previewCollapsed: true)
        XCTAssertEqual(RightPanelHeightCalculator.previewHeight(for: input), titleBar)
    }

    func testDragPreviewHeightOverridesStoredRatio() {
        let input = baseInput(ratio: 0.55, dragHeight: 300)
        XCTAssertEqual(RightPanelHeightCalculator.previewHeight(for: input), 300)
    }

    func testResizeDividerOnlyWhenBothExpanded() {
        XCTAssertTrue(RightPanelHeightCalculator.shouldShowResizeDivider(for: baseInput()))
        XCTAssertFalse(RightPanelHeightCalculator.shouldShowResizeDivider(for: baseInput(showSnippets: false)))
        XCTAssertFalse(RightPanelHeightCalculator.shouldShowResizeDivider(for: baseInput(previewCollapsed: true)))
        XCTAssertFalse(RightPanelHeightCalculator.shouldShowResizeDivider(for: baseInput(snippetsCollapsed: true)))
    }
}
