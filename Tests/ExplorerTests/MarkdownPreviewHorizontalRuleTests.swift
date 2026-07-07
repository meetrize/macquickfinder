import AppKit
import XCTest
@testable import Explorer

final class MarkdownPreviewHorizontalRuleTests: XCTestCase {
    private var font: NSFont {
        NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    func testDetectsCommonHorizontalRuleMarkers() {
        XCTAssertTrue(MarkdownPreviewHorizontalRule.isHorizontalRuleLine("---"))
        XCTAssertTrue(MarkdownPreviewHorizontalRule.isHorizontalRuleLine("***"))
        XCTAssertTrue(MarkdownPreviewHorizontalRule.isHorizontalRuleLine("___"))
        XCTAssertTrue(MarkdownPreviewHorizontalRule.isHorizontalRuleLine("  ---  "))
    }

    func testDoesNotTreatHeadingOrTableSeparatorAsHorizontalRule() {
        XCTAssertFalse(MarkdownPreviewHorizontalRule.isHorizontalRuleLine("# Title"))
        XCTAssertFalse(MarkdownPreviewHorizontalRule.isHorizontalRuleLine("| --- | --- |"))
    }

    func testFrontMatterLinesAreExcludedFromHorizontalRules() {
        let lines = [
            "---",
            "title: Hello",
            "---",
            "",
            "---",
        ]

        let frontMatter = MarkdownPreviewHorizontalRule.frontMatterLineIndices(in: lines)
        XCTAssertEqual(frontMatter, [0, 1, 2])

        let hrLines = MarkdownPreviewHorizontalRule.horizontalRuleLineIndices(in: lines)
        XCTAssertEqual(hrLines, [4])
    }

    func testRenderLineUsesBoxDrawingCharacters() {
        let rendered = MarkdownPreviewHorizontalRule.renderLine(
            indent: "",
            availableWidth: 240,
            font: font
        )
        XCTAssertTrue(rendered.contains("─"))
        XCTAssertFalse(rendered.contains("-"))
    }

    func testHorizontalRulesInsideFenceAreIgnored() {
        let lines = [
            "```",
            "---",
            "```",
            "---",
        ]

        let hrLines = MarkdownPreviewHorizontalRule.horizontalRuleLineIndices(in: lines)
        XCTAssertEqual(hrLines, [3])
    }
}
