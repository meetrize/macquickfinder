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
}
