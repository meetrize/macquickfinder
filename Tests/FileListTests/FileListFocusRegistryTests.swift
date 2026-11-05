import XCTest
@testable import FileList

@MainActor
final class FileListFocusRegistryTests: XCTestCase {
    func testClaimActiveSwitchesActiveTable() {
        let first = FileListTableController()
        let second = FileListTableController()
        XCTAssertTrue(FileListFocusRegistry.allTables.contains { $0 === first })
        XCTAssertTrue(FileListFocusRegistry.allTables.contains { $0 === second })
        XCTAssertTrue(FileListFocusRegistry.activeTable === second)

        FileListFocusRegistry.claimActive(first)
        XCTAssertTrue(FileListFocusRegistry.activeTable === first)

        FileListFocusRegistry.unregister(first)
        FileListFocusRegistry.unregister(second)
    }

    func testForEachTableVisitsAllRegistered() {
        let first = FileListTableController()
        let second = FileListTableController()
        var seen = 0
        FileListFocusRegistry.forEachTable { _ in seen += 1 }
        XCTAssertGreaterThanOrEqual(seen, 2)
        FileListFocusRegistry.unregister(first)
        FileListFocusRegistry.unregister(second)
    }

    func testSelectedTabWindowNilIsInactive() {
        XCTAssertFalse(FileListFocusRegistry.isSelectedTabWindow(nil))
    }

    func testForEachSelectedTabTableSkipsWhenNoWindow() {
        // 未挂 window 的控制器视为可更新（首帧），仍会被 selected-tab 遍历命中。
        let table = FileListTableController()
        var seen = 0
        FileListFocusRegistry.forEachSelectedTabTable { controller in
            if controller === table { seen += 1 }
        }
        XCTAssertEqual(seen, 1)
        FileListFocusRegistry.unregister(table)
    }
}
