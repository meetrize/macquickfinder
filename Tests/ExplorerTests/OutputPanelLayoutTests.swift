import XCTest
@testable import Explorer

final class OutputPanelLayoutTests: XCTestCase {
    func testClampedPanelHeightReservesMainContentMinimum() {
        let clamped = OutputPanelMetrics.clampedPanelHeight(
            desired: 400,
            containerHeight: 320,
            isContentCollapsed: false
        )
        XCTAssertEqual(clamped, 200, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(
            320 - clamped,
            OutputPanelMetrics.minimumMainContentHeight
        )
    }

    func testClampedPanelHeightCollapsedUsesTitleBarOnly() {
        let clamped = OutputPanelMetrics.clampedPanelHeight(
            desired: 400,
            containerHeight: 80,
            isContentCollapsed: true
        )
        XCTAssertEqual(clamped, OutputPanelMetrics.titleBarHeight)
    }

    func testMaxPanelHeightReservesMainContentMinimum() {
        let maxHeight = OutputPanelMetrics.maxPanelHeight(forContainerHeight: 320)
        XCTAssertEqual(maxHeight, 200, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(
            320 - maxHeight,
            OutputPanelMetrics.minimumMainContentHeight
        )
    }
}
