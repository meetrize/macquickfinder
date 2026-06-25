import XCTest
@testable import Explorer

final class LeftPanelStateMachineTests: XCTestCase {
    func testSidebarToRailToHiddenByDraggingLeft() {
        var constants = LeftPanelLayoutConstants()
        constants.sidebarMinWidth = 80
        constants.hideThreshold = 28
        constants.sidebarToRailHysteresis = 4
        
        // 从 sidebar 开始，向左拖到略小于 minWidth - hysteresis 应进入 rail
        let toRail = LeftPanelStateMachine.applyDrag(
            proposedWidth: 75,
            currentMode: .sidebar,
            lastVisible: .sidebar,
            sidebarWidth: 240,
            constants: constants
        )
        XCTAssertEqual(toRail.mode, .rail)
        XCTAssertEqual(toRail.lastVisible, .rail)
        
        // 继续向左拖到 hideThreshold 以下应进入 hidden
        let toHidden = LeftPanelStateMachine.applyDrag(
            proposedWidth: 20,
            currentMode: .rail,
            lastVisible: toRail.lastVisible,
            sidebarWidth: toRail.sidebarWidth,
            constants: constants
        )
        XCTAssertEqual(toHidden.mode, .hidden)
        XCTAssertEqual(toHidden.lastVisible, .rail)
    }
    
    func testRailToSidebarByDraggingRightBeyondMinWidth() {
        var constants = LeftPanelLayoutConstants()
        constants.sidebarMinWidth = 80
        constants.railToSidebarHysteresis = 8
        
        let result = LeftPanelStateMachine.applyDrag(
            proposedWidth: 90,
            currentMode: .rail,
            lastVisible: .rail,
            sidebarWidth: 240,
            constants: constants
        )
        XCTAssertEqual(result.mode, .sidebar)
        XCTAssertEqual(result.lastVisible, .sidebar)
        XCTAssertGreaterThanOrEqual(result.sidebarWidth, constants.sidebarMinWidth)
    }
    
    func testSidebarStaysSidebarWhenAtMinWidthBand() {
        var constants = LeftPanelLayoutConstants()
        constants.sidebarMinWidth = 80
        constants.sidebarToRailHysteresis = 4
        
        // proposed 77 在 minWidth - 4 之上，不应切 rail，但宽度应 clamp 到 minWidth
        let result = LeftPanelStateMachine.applyDrag(
            proposedWidth: 77,
            currentMode: .sidebar,
            lastVisible: .sidebar,
            sidebarWidth: 240,
            constants: constants
        )
        XCTAssertEqual(result.mode, .sidebar)
        XCTAssertEqual(result.sidebarWidth, 80, accuracy: 0.001)
    }
    
    func testSidebarKeepsTextAtModerateWidth() {
        var constants = LeftPanelLayoutConstants()
        constants.sidebarMinWidth = 80
        
        let result = LeftPanelStateMachine.applyDrag(
            proposedWidth: 195,
            currentMode: .sidebar,
            lastVisible: .sidebar,
            sidebarWidth: 240,
            constants: constants
        )
        XCTAssertEqual(result.mode, .sidebar)
        XCTAssertEqual(result.sidebarWidth, 195, accuracy: 0.001)
    }
    
    func testRailDisplayWidthDoesNotGoBelowRailWidth() {
        var constants = LeftPanelLayoutConstants()
        constants.railWidth = 44
        constants.hideThreshold = 28
        
        XCTAssertEqual(constants.railDisplayWidth(liveDragWidth: 80), 80, accuracy: 0.001)
        XCTAssertEqual(constants.railDisplayWidth(liveDragWidth: 44), 44, accuracy: 0.001)
        XCTAssertEqual(constants.railDisplayWidth(liveDragWidth: 35), 44, accuracy: 0.001)
        XCTAssertEqual(constants.railDisplayWidth(liveDragWidth: 20), 44, accuracy: 0.001)
    }
}

