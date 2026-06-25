import AppKit
import Foundation

/// 列表/缩略图重命名 UI 适配：选中、激活编辑器、结束编辑等由具体模式实现。
protocol FileListRenameUIAdapter: AnyObject {
    var renameInteraction: FileListTableInteraction { get }
    var renameCoordinator: FileListRenameCoordinator { get }
    var renamingRowID: String? { get set }
    var isRenaming: Bool { get }

    func renameRow(matching id: String) -> FileListRow?
    func renameEnsureSelected(row: FileListRow)
    func renameClearPendingTarget()
    func renameActivateEditor(for row: FileListRow)
    func renameDeactivateEditor(forRowID rowID: String)
    func renameRetryBegin(forRowID rowID: String)
}

/// 共享 begin / cancel / commit 编排；模式差异通过 `FileListRenameUIAdapter` 注入。
enum FileListRenamePresenter {
    static func beginRename(row: FileListRow, adapter: FileListRenameUIAdapter) {
        guard !adapter.isRenaming else { return }
        guard !row.isParentDirectoryEntry else { return }
        guard adapter.renameInteraction.canRename(row) else { return }
        guard adapter.renamingRowID != row.id else { return }

        adapter.renameEnsureSelected(row: row)
        adapter.renamingRowID = row.id
        adapter.renameClearPendingTarget()
        adapter.renameInteraction.onRenameEditingChanged(true)
        adapter.renameActivateEditor(for: row)
    }

    static func cancelRename(adapter: FileListRenameUIAdapter) {
        guard let rowID = adapter.renamingRowID else { return }
        adapter.renamingRowID = nil
        adapter.renameDeactivateEditor(forRowID: rowID)
        adapter.renameClearPendingTarget()
        adapter.renameInteraction.onRenameEditingChanged(false)
    }

    static func commitRename(newName: String, adapter: FileListRenameUIAdapter) {
        guard let rowID = adapter.renamingRowID,
              let row = adapter.renameRow(matching: rowID) else { return }

        switch FileListRenameCoordinator.evaluateCommit(newName: newName, originalName: row.name) {
        case .cancel:
            cancelRename(adapter: adapter)
        case .commit(let trimmed):
            adapter.renamingRowID = nil
            adapter.renameClearPendingTarget()
            adapter.renameDeactivateEditor(forRowID: rowID)
            adapter.renameInteraction.onRenameEditingChanged(false)
            adapter.renameInteraction.performRename(row, trimmed) { success in
                guard !success else { return }
                adapter.renameRetryBegin(forRowID: rowID)
            }
        }
    }

    static func cancelIfNeededForDataUpdate(adapter: FileListRenameUIAdapter) {
        adapter.renameCoordinator.cancelForDataUpdate { editing in
            adapter.renameClearPendingTarget()
            adapter.renameInteraction.onRenameEditingChanged(editing)
        }
    }
}
