import AppKit
import Foundation

extension FileListTableController: FileListRenameUIAdapter {
    var renameInteraction: FileListTableInteraction { interaction }

    func renameRow(matching id: String) -> FileListRow? {
        guard let index = displayRows.firstIndex(where: { $0.id == id }) else { return nil }
        return displayRows[index]
    }

    func renameEnsureSelected(row: FileListRow) {
        guard let tableView,
              let index = displayRows.firstIndex(where: { $0.id == row.id }) else { return }
        if !tableView.selectedRowIndexes.contains(index) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            syncSelectionFromTable()
        }
    }

    func renameClearPendingTarget() {
        pendingRenameRow = -1
    }

    func renameActivateEditor(for row: FileListRow) {
        guard let index = displayRows.firstIndex(where: { $0.id == row.id }) else { return }
        refreshRenameRow(index)
        DispatchQueue.main.async { [weak self] in
            self?.focusRenameField(forRow: index)
        }
    }

    func renameDeactivateEditor(forRowID rowID: String) {
        guard let index = displayRows.firstIndex(where: { $0.id == rowID }) else { return }
        endRenameFieldEditing(forRow: index)
        refreshRenameRow(index)
    }

    func renameRetryBegin(forRowID rowID: String) {
        guard let index = displayRows.firstIndex(where: { $0.id == rowID }) else { return }
        beginRename(row: index)
    }

    public func beginRename(itemID: String) {
        guard let row = renameRow(matching: itemID) else { return }
        FileListRenamePresenter.beginRename(row: row, adapter: self)
    }

    func beginRename(row: Int) {
        guard row >= 0, row < displayRows.count else { return }
        FileListRenamePresenter.beginRename(row: displayRows[row], adapter: self)
    }

    func cancelRename() {
        FileListRenamePresenter.cancelRename(adapter: self)
    }

    func commitRename(newName: String) {
        FileListRenamePresenter.commitRename(newName: newName, adapter: self)
    }

    func shouldBeginRenameOnMouseUp(row: Int, pointInTable: NSPoint) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        guard let tableView else { return false }
        let item = displayRows[row]
        return renameCoordinator.shouldBeginRenameOnMouseUp(
            isSoleSelection: tableView.selectedRowIndexes == IndexSet(integer: row),
            isNameClickPoint: isRenameNameClickPoint(pointInTable, row: row, in: tableView),
            canRename: interaction.canRename(item),
            isParentDirectory: item.isParentDirectoryEntry,
            itemID: item.id
        )
    }

    func armRenameEligibleAfterClickIfNeeded(_ event: NSEvent, row: Int, pointInTable: NSPoint) {
        guard row >= 0, row < displayRows.count else { return }
        guard let tableView else { return }
        let item = displayRows[row]
        renameCoordinator.armEligibleAfterClickIfNeeded(
            wasAlreadySelectedAtMouseDown: wasAlreadySelectedAtMouseDown,
            event: event,
            hasPendingRename: pendingRenameRow >= 0,
            isSoleSelection: tableView.selectedRowIndexes == IndexSet(integer: row),
            isNameClickPoint: isRenameNameClickPoint(pointInTable, row: row, in: tableView),
            canRename: interaction.canRename(item),
            isParentDirectory: item.isParentDirectoryEntry,
            itemID: item.id
        )
    }

    func recordRenameSelectionTimestamps() {
        guard let tableView else { return }
        let currentIDs = Set(
            tableView.selectedRowIndexes.compactMap { row -> String? in
                guard row >= 0, row < displayRows.count else { return nil }
                return displayRows[row].id
            }
        )
        renameCoordinator.recordSelectionTimestamps(currentIDs: currentIDs)
    }

    func isRenameSecondClickEligible(itemID: String) -> Bool {
        renameCoordinator.isSecondClickEligible(itemID: itemID)
    }

    func renameField(in cell: NSTableCellView) -> FileListInlineRenameField? {
        cell.subviews.compactMap { $0 as? FileListInlineRenameField }.first
    }

    func renameFieldMaxWidth(in cell: NSTableCellView) -> CGFloat {
        let iconLeading: CGFloat = 2
        let iconWidth: CGFloat = 18
        let iconGap: CGFloat = 4
        let trailingMargin: CGFloat = 4
        return max(0, cell.bounds.width - iconLeading - iconWidth - iconGap - trailingMargin)
    }

    func refreshRenameRow(_ row: Int) {
        guard let tableView else { return }
        guard let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
            FileListColumnID.from(column: $0) == .name
        }) else { return }

        guard row >= 0, row < displayRows.count,
              let cell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: true) as? NSTableCellView
        else { return }

        configure(cell: cell, columnID: .name, item: displayRows[row], row: row)
    }

    func focusRenameField(forRow row: Int) {
        guard let tableView else { return }
        guard let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
            FileListColumnID.from(column: $0) == .name
        }) else { return }

        guard let cell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: true) as? NSTableCellView,
              let field = renameField(in: cell) else { return }
        field.updateLayoutWidth(maxAvailableWidth: renameFieldMaxWidth(in: cell))
        tableView.window?.makeFirstResponder(field)
    }

    func endRenameFieldEditing(forRow row: Int) {
        guard let tableView else { return }
        guard let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
            FileListColumnID.from(column: $0) == .name
        }) else { return }
        guard let cell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView,
              let field = renameField(in: cell) else { return }
        field.suppressEndEditingCommit = true
        tableView.window?.makeFirstResponder(tableView)
    }

    public func cancelRenameIfNeededForDataUpdate() {
        FileListRenamePresenter.cancelIfNeededForDataUpdate(adapter: self)
    }
}
