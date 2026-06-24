import XCTest
@testable import Explorer

final class OutputPanelLayoutTests: XCTestCase {
    func testClampedPanelHeightKeepsBottomBarOnShrink() {
        let clamped = OutputPanelMetrics.clampedPanelHeight(
            desired: 400,
            containerHeight: 120,
            isContentCollapsed: false
        )
        XCTAssertEqual(clamped, 120, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(clamped, OutputPanelMetrics.bottomBarHeight)
    }

    func testClampedPanelHeightCollapsedUsesTitleBarOnly() {
        let clamped = OutputPanelMetrics.clampedPanelHeight(
            desired: 400,
            containerHeight: 80,
            isContentCollapsed: true
        )
        XCTAssertEqual(clamped, OutputPanelMetrics.titleBarHeight)
    }

    func testTotalOverlayHeightMatchesPanelHeight() {
        let total = OutputPanelMetrics.totalOverlayHeight(
            panelHeight: 200,
            isContentCollapsed: false
        )
        XCTAssertEqual(total, 200)
    }
}
