import AppKit
import XCTest
@testable import Explorer

final class HelpCheatSheetLayoutEngineTests: XCTestCase {
    func testLayoutUsesSingleColumnForNarrowWidth() {
        let layout = HelpCheatSheetLayoutEngine.layout(for: 520)
        XCTAssertEqual(layout.columns.count, 1)
        XCTAssertEqual(layout.columns.first?.sections.count, HelpCheatSheetContent.sections.count)
    }

    func testLayoutUsesThreeColumnsForFullscreenWidth() {
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1_600
        let layout = HelpCheatSheetLayoutEngine.layout(for: screenWidth)
        XCTAssertEqual(layout.columns.count, 3)
    }

    func testLayoutContentWidthMatchesColumnWidths() {
        let layout = HelpCheatSheetLayoutEngine.layout(for: 1_600)
        let expected = layout.columns.reduce(0) { $0 + $1.width }
            + HelpCheatSheetLayoutEngine.columnGap * CGFloat(max(layout.columns.count - 1, 0))
        XCTAssertEqual(layout.contentWidth, expected, accuracy: 0.5)
    }

    func testSectionsAreDistributedWithoutSplitting() {
        let layout = HelpCheatSheetLayoutEngine.layout(for: 1_600)
        let sectionIDs = layout.columns.flatMap { $0.sections.map(\.id) }
        XCTAssertEqual(sectionIDs, HelpCheatSheetContent.sections.map(\.id))
    }

    func testPreferredWindowWidthIsCompact() {
        let threeColumnLayout = HelpCheatSheetLayoutEngine.layout(for: 2_000)
        let preferred = HelpCheatSheetLayoutEngine.preferredWindowWidth(forScreenWidth: 2_000)
        XCTAssertLessThanOrEqual(
            preferred,
            threeColumnLayout.contentWidth + HelpCheatSheetLayoutEngine.viewHorizontalPadding * 2 + 1
        )
    }
}
