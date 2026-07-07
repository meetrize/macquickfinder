import AppKit
import XCTest
@testable import Explorer

final class MarkdownPreviewTableLayoutTests: XCTestCase {
    private let separatorRegex = try? NSRegularExpression(
        pattern: "^\\s*\\|?\\s*:?-{2,}:?\\s*(\\|\\s*:?-{2,}:?\\s*)+\\|?\\s*$",
        options: []
    )

    private var monoFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    func testFindBlocksDetectsMultiRowTable() {
        let lines = [
            "# Title",
            "| Name | Age | City |",
            "| --- | --- | --- |",
            "| Alice | 30 | NYC |",
            "| Bob | 25 | SF |",
        ]

        let blocks = MarkdownPreviewTableLayout.findBlocks(in: lines, separatorRegex: separatorRegex)
        XCTAssertEqual(blocks, [MarkdownPreviewTableLayout.Block(startLine: 1, endLine: 5, indent: "")])
    }

    func testFormatBlockUsesTabsBetweenColumns() {
        let lines = [
            "| Name | Age |",
            "| --- | --- |",
            "| Alice | 30 |",
            "| 张三 | 25 |",
        ]
        let block = MarkdownPreviewTableLayout.Block(startLine: 0, endLine: 4, indent: "")

        guard let formatted = MarkdownPreviewTableLayout.formatBlock(
            lines: lines,
            block: block,
            font: monoFont
        ) else {
            return XCTFail("Expected formatted table block")
        }

        XCTAssertEqual(formatted.lines.count, 4)
        XCTAssertTrue(formatted.lines[0].contains("\t"), "Columns should be separated by tabs")
        XCTAssertTrue(formatted.lines[2].contains("\t"))
        XCTAssertTrue(formatted.lines[3].contains("\t"))
        XCTAssertFalse(formatted.tabStopLocations.isEmpty)
    }

    func testFormatBlockAlignsPipesAcrossRows() {
        let lines = [
            "| short | much longer |",
            "| --- | --- |",
            "| a | bb |",
        ]
        let block = MarkdownPreviewTableLayout.Block(startLine: 0, endLine: 3, indent: "")

        guard let formatted = MarkdownPreviewTableLayout.formatBlock(
            lines: lines,
            block: block,
            font: monoFont
        ) else {
            return XCTFail("Expected formatted table block")
        }

        func secondPipeLocation(_ line: String) -> Int? {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { return nil }
            return parts[0].count + parts[1].count + 1
        }

        XCTAssertEqual(
            secondPipeLocation(formatted.lines[0]),
            secondPipeLocation(formatted.lines[2]),
            "Second column pipes should align in monospace layout"
        )
    }

    func testFindBlocksIgnoresTablesInsideFence() {
        let lines = [
            "```",
            "| Name | Age |",
            "| --- | --- |",
            "```",
            "| Name | Age |",
            "| --- | --- |",
        ]

        let blocks = MarkdownPreviewTableLayout.findBlocks(in: lines, separatorRegex: separatorRegex)
        XCTAssertEqual(blocks, [MarkdownPreviewTableLayout.Block(startLine: 4, endLine: 6, indent: "")])
    }
}
