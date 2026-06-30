import CoreGraphics
import XCTest
@testable import Explorer

final class ImagePreviewDisplayMetricsTests: XCTestCase {
    func testPixelBudgetScalesWithContainerAndRetina() {
        let budget = ImagePreviewDisplayMetrics.pixelBudget(
            containerSize: CGSize(width: 400, height: 300),
            screenScale: 2
        )
        // max(400, 300) * 2 * 1.5 = 1200
        XCTAssertEqual(budget, 1200)
    }

    func testPixelBudgetCapsAtAbsoluteMaximum() {
        let budget = ImagePreviewDisplayMetrics.pixelBudget(
            containerSize: CGSize(width: 4000, height: 3000),
            screenScale: 2
        )
        XCTAssertEqual(budget, ImagePreviewDisplayMetrics.absoluteMaxPixelBudget)
    }

    func testPixelBudgetFloorsAtMinimum() {
        let budget = ImagePreviewDisplayMetrics.pixelBudget(
            containerSize: CGSize(width: 40, height: 30),
            screenScale: 1
        )
        XCTAssertEqual(budget, ImagePreviewDisplayMetrics.minimumPixelBudget)
    }

    func testPixelBudgetUsesZeroSizeFallbackMaximum() {
        let budget = ImagePreviewDisplayMetrics.pixelBudget(
            containerSize: .zero,
            screenScale: 2
        )
        XCTAssertEqual(budget, ImagePreviewDisplayMetrics.absoluteMaxPixelBudget)
    }
}
