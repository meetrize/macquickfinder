import XCTest
@testable import FileList

final class FileListRenamePresenterTests: XCTestCase {
    private final class MockAdapter: FileListRenameUIAdapter {
        var renameInteraction: FileListTableInteraction
        let renameCoordinator = FileListRenameCoordinator()
        var renamingRowID: String?
        var isRenaming: Bool { renamingRowID != nil }

        private(set) var activatedRow: FileListRow?
        private(set) var deactivatedRowID: String?
        private(set) var retryRowID: String?
        private(set) var clearedPending = false
        private(set) var editingChanges: [Bool] = []
        private(set) var performRenameCalls: [(FileListRow, String)] = []

        init() {
            renameInteraction = FileListTableInteraction(
                canRename: { _ in true },
                performRename: { [weak self] item, newName, completion in
                    self?.performRenameCalls.append((item, newName))
                    completion(true)
                },
                onRenameEditingChanged: { [weak self] editing in
                    self?.editingChanges.append(editing)
                }
            )
        }

        func renameRow(matching id: String) -> FileListRow? {
            sampleRow(id: id)
        }

        func renameEnsureSelected(row: FileListRow) {}

        func renameClearPendingTarget() {
            clearedPending = true
        }

        func renameActivateEditor(for row: FileListRow) {
            activatedRow = row
        }

        func renameDeactivateEditor(forRowID rowID: String) {
            deactivatedRowID = rowID
        }

        func renameRetryBegin(forRowID rowID: String) {
            retryRowID = rowID
        }

        private func sampleRow(id: String) -> FileListRow {
            FileListRow(
                id: id,
                name: "before.txt",
                fileType: "txt",
                sizeDisplay: "0",
                dateDisplay: "",
                size: 0,
                modificationDate: .distantPast,
                isDirectory: false,
                isHidden: false,
                isParentDirectoryEntry: false,
                iconPath: "/tmp/before.txt"
            )
        }
    }

    func testBeginRenameActivatesEditor() {
        let adapter = MockAdapter()
        let row = adapter.renameRow(matching: "a")!

        FileListRenamePresenter.beginRename(row: row, adapter: adapter)

        XCTAssertEqual(adapter.renamingRowID, "a")
        XCTAssertTrue(adapter.clearedPending)
        XCTAssertEqual(adapter.editingChanges, [true])
        XCTAssertEqual(adapter.activatedRow?.id, "a")
    }

    func testCommitRenameCancelsWhenNameUnchanged() {
        let adapter = MockAdapter()
        adapter.renamingRowID = "a"

        FileListRenamePresenter.commitRename(newName: "before.txt", adapter: adapter)

        XCTAssertNil(adapter.renamingRowID)
        XCTAssertEqual(adapter.editingChanges, [false])
        XCTAssertTrue(adapter.performRenameCalls.isEmpty)
    }

    func testCommitRenamePerformsTrimmedRename() {
        let adapter = MockAdapter()
        adapter.renamingRowID = "a"

        FileListRenamePresenter.commitRename(newName: "  after.txt  ", adapter: adapter)

        XCTAssertNil(adapter.renamingRowID)
        XCTAssertEqual(adapter.performRenameCalls.count, 1)
        XCTAssertEqual(adapter.performRenameCalls.first?.1, "after.txt")
        XCTAssertEqual(adapter.deactivatedRowID, "a")
    }

    func testCommitRenameRetriesOnFailure() {
        let adapter = MockAdapter()
        adapter.renamingRowID = "a"
        adapter.renameInteraction.performRename = { [weak adapter] item, newName, completion in
            adapter?.performRenameCalls.append((item, newName))
            completion(false)
        }

        FileListRenamePresenter.commitRename(newName: "after.txt", adapter: adapter)

        XCTAssertEqual(adapter.retryRowID, "a")
    }
}
