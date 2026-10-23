import XCTest
@testable import Explorer

@MainActor
final class DualPaneLayoutStateTests: XCTestCase {
    func testDualPanePreferencesRoundTrip() {
        let defaults = UserDefaults(suiteName: "DualPaneLayoutStateTests.\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.suiteName!) }

        let layout = ExplorerWindowLayoutState(defaults: defaults)
        XCTAssertFalse(layout.isDualPaneEnabled)
        XCTAssertEqual(layout.dualPaneSplitRatio, 0.5, accuracy: 0.001)

        layout.isDualPaneEnabled = true
        layout.dualPaneSplitRatio = 0.35
        layout.dualPaneSecondaryPath = "/Volumes/Test"

        let restored = ExplorerWindowLayoutState(defaults: defaults)
        XCTAssertTrue(restored.isDualPaneEnabled)
        XCTAssertEqual(restored.dualPaneSplitRatio, 0.35, accuracy: 0.001)
        XCTAssertEqual(restored.dualPaneSecondaryPath, "/Volumes/Test")
    }

    func testEqualizeDualPaneSplit() {
        let defaults = UserDefaults(suiteName: "DualPaneEqualize.\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.suiteName!) }
        let layout = ExplorerWindowLayoutState(defaults: defaults)
        layout.dualPaneSplitRatio = 0.7
        layout.equalizeDualPaneSplit()
        XCTAssertEqual(layout.dualPaneSplitRatio, 0.5, accuracy: 0.001)
    }
}
