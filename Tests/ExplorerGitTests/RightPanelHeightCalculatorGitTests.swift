import XCTest
@testable import Explorer

final class RightPanelHeightCalculatorGitTests: XCTestCase {
    private let total: CGFloat = 800
    private let titleBar: CGFloat = PanelTopBarMetrics.totalHeight
    private let divider: CGFloat = VerticalResizeDividerMetrics.visualHeight

    private func baseInput(
        showPreview: Bool = true,
        showSnippets: Bool = true,
        showGit: Bool = true,
        previewCollapsed: Bool = false,
        snippetsCollapsed: Bool = false,
        gitCollapsed: Bool = false,
        gitPanelHeight: CGFloat = GitPanelMetrics.defaultHeight
    ) -> RightPanelHeightCalculator.Input {
        RightPanelHeightCalculator.Input(
            totalHeight: total,
            showPreview: showPreview,
            showSnippets: showSnippets,
            showGit: showGit,
            isPreviewContentCollapsed: previewCollapsed,
            isSnippetsContentCollapsed: snippetsCollapsed,
            isGitContentCollapsed: gitCollapsed,
            previewSnippetsSplitRatio: 0.55,
            gitPanelHeight: gitPanelHeight,
            dragPreviewHeight: nil,
            dividerHeight: divider,
            previewMinHeight: 80,
            snippetsMinHeight: 80,
            gitMinHeight: GitPanelMetrics.minHeight,
            collapsedTitleBarHeight: titleBar
        )
    }

    func testGitOnlyFillsEntirePanel() {
        let input = baseInput(showPreview: false, showSnippets: false, showGit: true)
        XCTAssertEqual(RightPanelHeightCalculator.gitHeight(for: input), total)
        XCTAssertEqual(RightPanelHeightCalculator.previewHeight(for: input), 0)
    }

    func testGitCollapsedUsesTitleBarHeight() {
        let input = baseInput(gitCollapsed: true)
        XCTAssertEqual(RightPanelHeightCalculator.gitHeight(for: input), titleBar)
    }

    func testPreviewHeightReservesGitSection() {
        let input = baseInput(showGit: true, gitPanelHeight: 200)
        let gitHeight = RightPanelHeightCalculator.gitHeight(for: input)
        let previewHeight = RightPanelHeightCalculator.previewHeight(for: input)
        let upperHeight = RightPanelHeightCalculator.upperSectionHeight(for: input)
        XCTAssertEqual(gitHeight, 200, accuracy: 0.01)
        XCTAssertEqual(previewHeight, upperHeight * 0.55, accuracy: 0.01)
        XCTAssertEqual(previewHeight + gitHeight, upperHeight * 0.55 + 200, accuracy: 1)
    }

    func testGitHiddenMatchesLegacyPreviewHeight() {
        let withGit = baseInput(showGit: true, gitPanelHeight: 200)
        var withoutGit = withGit
        withoutGit.showGit = false
        XCTAssertGreaterThan(
            RightPanelHeightCalculator.previewHeight(for: withGit),
            0
        )
        XCTAssertEqual(
            RightPanelHeightCalculator.previewHeight(for: withoutGit),
            total * 0.55,
            accuracy: 0.01
        )
    }

    func testSnippetsGitDividerVisibleWhenBothExpanded() {
        let input = baseInput(showSnippets: true, showGit: true)
        XCTAssertTrue(RightPanelHeightCalculator.shouldShowSnippetsGitDivider(for: input))
    }

    func testSnippetsGitDividerHiddenWhenGitCollapsed() {
        let input = baseInput(showGit: true, gitCollapsed: true)
        XCTAssertFalse(RightPanelHeightCalculator.shouldShowSnippetsGitDivider(for: input))
    }

    func testSnippetsHeightWithinLowerStack() {
        let input = baseInput(showGit: true, gitPanelHeight: 200)
        let lower = RightPanelHeightCalculator.lowerStackHeight(for: input)
        let snippets = RightPanelHeightCalculator.snippetsHeight(for: input)
        let git = RightPanelHeightCalculator.gitHeight(for: input)
        let divider = RightPanelHeightCalculator.gitDividerHeight(for: input)
        XCTAssertEqual(snippets + git + divider, lower, accuracy: 1)
    }

    func testAllocatedStackHeightMatchesTotalForAllPanels() {
        let input = baseInput(showGit: true, gitPanelHeight: 200)
        XCTAssertEqual(
            RightPanelHeightCalculator.allocatedStackHeight(for: input),
            total,
            accuracy: 1
        )
    }

    func testPreviewGitDividerWhenSnippetsHidden() {
        let input = baseInput(showSnippets: false, showGit: true, gitPanelHeight: 200)
        let lower = RightPanelHeightCalculator.lowerStackHeight(for: input)
        XCTAssertTrue(RightPanelHeightCalculator.shouldShowPreviewGitDivider(for: input))
        XCTAssertEqual(RightPanelHeightCalculator.previewGitRegionHeight(for: input), lower, accuracy: 0.01)
        let preview = RightPanelHeightCalculator.previewHeight(for: input)
        let git = RightPanelHeightCalculator.gitHeight(for: input)
        let divider = RightPanelHeightCalculator.previewGitDividerHeight(for: input)
        XCTAssertEqual(preview + git + divider, total, accuracy: 1)
        XCTAssertEqual(preview + divider + git, lower, accuracy: 1)
    }

    func testPreviewGitDividerHiddenWhenSnippetsVisible() {
        let input = baseInput(showSnippets: true, showGit: true)
        XCTAssertFalse(RightPanelHeightCalculator.shouldShowPreviewGitDivider(for: input))
    }

    func testGitHeightNotCappedAtLegacyMax() {
        let input = baseInput(showSnippets: false, showGit: true, gitPanelHeight: 500)
        let git = RightPanelHeightCalculator.gitHeight(for: input)
        XCTAssertGreaterThan(git, 360)
    }
}
