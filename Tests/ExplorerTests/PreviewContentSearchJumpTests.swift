import XCTest
import AppKit
@testable import Explorer

final class PreviewContentSearchJumpTests: XCTestCase {
    func testFirstMatchIndexOnLineFindsMatchOnTargetLine() {
        let text = "alpha\nTODO here\nbeta TODO"
        let ranges = PreviewTextSearchHighlighter.findMatchRanges(of: "TODO", in: text)
        let index = PreviewTextSearchHighlighter.firstMatchIndexOnLine(
            lineNumber: 2,
            in: text,
            matchRanges: ranges
        )
        XCTAssertEqual(index, 0)
    }

    func testMatchIndexPrefersColumnOnSameLine() {
        let text = "xx TODO yy TODO zz"
        let ranges = PreviewTextSearchHighlighter.findMatchRanges(of: "TODO", in: text)
        XCTAssertEqual(ranges.count, 2)

        let first = PreviewTextSearchHighlighter.matchIndex(
            lineNumber: 1,
            columnUTF16: ranges[0].location,
            in: text,
            matchRanges: ranges
        )
        let second = PreviewTextSearchHighlighter.matchIndex(
            lineNumber: 1,
            columnUTF16: ranges[1].location,
            in: text,
            matchRanges: ranges
        )
        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 1)
    }

    func testMatchIndexFallsBackToFirstOnLineWhenColumnMisses() {
        let text = "alpha\nTODO here\nbeta"
        let ranges = PreviewTextSearchHighlighter.findMatchRanges(of: "TODO", in: text)
        let index = PreviewTextSearchHighlighter.matchIndex(
            lineNumber: 2,
            columnUTF16: 999,
            in: text,
            matchRanges: ranges
        )
        XCTAssertEqual(index, 0)
    }

    func testCanRevealLineReturnsFalseForEmptyText() {
        XCTAssertFalse(PreviewTextSearchHighlighter.canRevealLine(1, in: ""))
    }

    func testCanRevealLineFindsExistingLine() {
        let text = "alpha\nTODO here\nbeta"
        XCTAssertTrue(PreviewTextSearchHighlighter.canRevealLine(2, in: text))
        XCTAssertFalse(PreviewTextSearchHighlighter.canRevealLine(5, in: text))
    }

    func testFirstMatchIndexOnLineReturnsNilForMissingLine() {
        let text = "only line"
        let ranges = PreviewTextSearchHighlighter.findMatchRanges(of: "line", in: text)
        let index = PreviewTextSearchHighlighter.firstMatchIndexOnLine(
            lineNumber: 5,
            in: text,
            matchRanges: ranges
        )
        XCTAssertNil(index)
    }
}
