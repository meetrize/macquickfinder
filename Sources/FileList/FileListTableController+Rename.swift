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
    
    func shouldBeginRenameOnMouseUp(row: Int, pointInTable: NSPoint) -> Bool {
        guard !isRenaming else { return false }
        guard row >= 0, row < displayRows.count else { return false }
        guard let tableView else { return false }
        guard tableView.selectedRowIndexes == IndexSet(integer: row) else { return false }
        guard isRenameNameClickPoint(pointInTable, row: row, in: tableView) else { return false }
        
        let item = displayRows[row]
        guard !item.isParentDirectoryEntry else { return false }
        guard interaction.canRename(item) else { return false }
        return isRenameSecondClickEligible(itemID: item.id)
    }
    
    func armRenameEligibleAfterClickIfNeeded(_ event: NSEvent, row: Int, pointInTable: NSPoint) {
        guard renamingRowID == nil, pendingRenameRow < 0 else { return }
        guard wasAlreadySelectedAtMouseDown else { return }
        guard event.clickCount == 1 else { return }
        let flags = event.modifierFlags
        guard !flags.contains(.command), !flags.contains(.shift) else { return }
        guard let tableView else { return }
        guard row >= 0, row < displayRows.count else { return }
        guard tableView.selectedRowIndexes == IndexSet(integer: row) else { return }
        guard isRenameNameClickPoint(pointInTable, row: row, in: tableView) else { return }
        
        let item = displayRows[row]
        guard !item.isParentDirectoryEntry, interaction.canRename(item) else { return }
        rowRenameEligibleSince[item.id] = Date()
    }
    
    func recordRenameSelectionTimestamps() {
        guard let tableView else { return }
        let currentIDs = Set(
            tableView.selectedRowIndexes.compactMap { row -> String? in
                guard row >= 0, row < displayRows.count else { return nil }
                return displayRows[row].id
            }
        )
        let now = Date()
        for id in currentIDs.subtracting(lastKnownSelectionIDs) {
            rowRenameEligibleSince[id] = now
        }
        for id in lastKnownSelectionIDs.subtracting(currentIDs) {
            rowRenameEligibleSince.removeValue(forKey: id)
        }
        lastKnownSelectionIDs = currentIDs
    }
    
    /// 与 Finder / 资源管理器一致：须距上次选中（或同名点击）超过系统双击间隔，才视为「慢速二次点击改名」。
    func isRenameSecondClickEligible(itemID: String) -> Bool {
        guard let selectedAt = rowRenameEligibleSince[itemID] else { return false }
        return Date().timeIntervalSince(selectedAt) > NSEvent.doubleClickInterval
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
