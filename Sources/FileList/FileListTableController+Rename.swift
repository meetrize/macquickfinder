import AppKit
import Foundation

extension FileListTableController {
    var isRenaming: Bool { renamingRowID != nil }
    
    public func beginRename(itemID: String) {
        guard renamingRowID == nil else { return }
        guard let row = displayRows.firstIndex(where: { $0.id == itemID }) else { return }
        guard let tableView else { return }
        
        if !tableView.selectedRowIndexes.contains(row) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            syncSelectionFromTable()
        }
        beginRename(row: row)
    }
    
    func beginRename(row: Int) {
        guard row >= 0, row < displayRows.count else { return }
        let item = displayRows[row]
        guard !item.isParentDirectoryEntry else { return }
        guard interaction.canRename(item) else { return }
        guard renamingRowID != item.id else { return }
        
        renamingRowID = item.id
        pendingRenameRow = -1
        interaction.onRenameEditingChanged(true)
        refreshRenameRow(row)
        
        DispatchQueue.main.async { [weak self] in
            self?.focusRenameField(forRow: row)
        }
    }
    
    func cancelRename() {
        guard let rowID = renamingRowID else { return }
        let row = displayRows.firstIndex(where: { $0.id == rowID })
        
        if let row {
            endRenameFieldEditing(forRow: row)
        }
        
        renamingRowID = nil
        pendingRenameRow = -1
        interaction.onRenameEditingChanged(false)
        if let row {
            refreshRenameRow(row)
        }
    }
    
    func commitRename(newName: String) {
        guard let rowID = renamingRowID,
              let row = displayRows.firstIndex(where: { $0.id == rowID }) else { return }
        let item = displayRows[row]
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty || trimmed == item.name {
            cancelRename()
            return
        }
        
        renamingRowID = nil
        pendingRenameRow = -1
        endRenameFieldEditing(forRow: row)
        interaction.onRenameEditingChanged(false)
        refreshRenameRow(row)
        
        interaction.performRename(item, trimmed) { [weak self] success in
            guard let self, !success else { return }
            self.beginRename(row: row)
        }
    }
    
    func shouldBeginRenameOnMouseUp(row: Int) -> Bool {
        guard !isRenaming else { return false }
        guard row >= 0, row < displayRows.count else { return false }
        guard mouseDownCanStartFileDrag else { return false }
        guard let tableView else { return false }
        guard tableView.selectedRowIndexes == IndexSet(integer: row) else { return false }
        
        let item = displayRows[row]
        guard !item.isParentDirectoryEntry else { return false }
        return interaction.canRename(item)
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
    
    private func endRenameFieldEditing(forRow row: Int) {
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
        guard renamingRowID != nil else { return }
        renamingRowID = nil
        pendingRenameRow = -1
        interaction.onRenameEditingChanged(false)
    }
}
