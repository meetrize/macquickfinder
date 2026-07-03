import AppKit
import Foundation

// MARK: - Interaction state

extension FileListTableController {
    func commitRenameIfNeededForClick(pointInTable: NSPoint, in tableView: NSTableView) {
        guard isRenaming else { return }
        guard let frame = activeRenameFieldFrame(in: tableView), frame.contains(pointInTable) else {
            skipRenameArmOnCurrentMouseUp = true
            commitActiveRenameIfPossible()
            return
        }
    }

    func commitActiveRenameIfPossible() {
        guard isRenaming else { return }
        guard let field = activeRenameField() else {
            cancelRename()
            return
        }
        commitRename(newName: field.stringValue)
    }

    private func activeRenameField() -> FileListInlineRenameField? {
        guard let rowID = renamingRowID,
              let tableView,
              let row = displayRows.firstIndex(where: { $0.id == rowID }),
              let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
                  FileListColumnID.from(column: $0) == .name
              }),
              let cell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView,
              let field = renameField(in: cell),
              !field.isHidden
        else { return nil }
        return field
    }

    private func activeRenameFieldFrame(in tableView: NSTableView) -> NSRect? {
        guard let rowID = renamingRowID,
              let row = displayRows.firstIndex(where: { $0.id == rowID }),
              let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
                  FileListColumnID.from(column: $0) == .name
              }),
              let cell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView,
              let field = renameField(in: cell),
              !field.isHidden
        else { return nil }
        return field.convert(field.bounds, to: tableView)
    }

    // MARK: - Mouse & keyboard
    
    func handleTableFocusChanged(_ isFocused: Bool) {
        if !isFocused {
            clearRowHoverHighlight()
        } else {
            refreshRowHoverHighlightFromCurrentMouseLocation()
        }
        interaction.onTableFocusChanged(isFocused)
    }
    
    func willHandleMouseDown(_ event: NSEvent, row: Int, pointInTable: NSPoint) {
        mouseDownHandledByDisclosureToggle = false
        wasAlreadySelectedAtMouseDown = row >= 0 && row < displayRows.count && {
            guard let tableView else { return false }
            if tableView.selectedRowIndexes.contains(row) { return true }
            return effectiveSelectionIDs() == [displayRows[row].id]
        }()
        if let tableView, row >= 0, row < displayRows.count,
           isDisclosureTogglePoint(pointInTable, row: row, in: tableView) {
            interaction.onToggleExpand(displayRows[row])
            mouseDownHandledByDisclosureToggle = true
            mouseDownCanStartFileDrag = false
            mouseDownRow = row
            mouseDownLocation = nil
            mouseDownEvent = nil
            dragSessionActive = false
            blankMouseDownEvent = nil
            blankDragSelecting = false
            pendingRenameRow = -1
            return
        }
        if let tableView, row >= 0, row < displayRows.count {
            mouseDownCanStartFileDrag = isFileDragStartPoint(pointInTable, row: row, in: tableView)
        } else {
            mouseDownCanStartFileDrag = false
        }
        mouseDownRow = row
        mouseDownLocation = event.locationInWindow
        mouseDownEvent = event
        dragSessionActive = false
        
        // 在行内非图标/文件名文字区按下时，拖动应进入框选而非文件拖拽。
        if row >= 0, !mouseDownCanStartFileDrag {
            blankMouseDownEvent = event
            blankDragSelecting = false
        } else {
            blankMouseDownEvent = nil
            blankDragSelecting = false
        }
    }

    func shouldUseDefaultMouseDown(for row: Int, event: NSEvent) -> Bool {
        if mouseDownHandledByDisclosureToggle { return false }
        guard row >= 0, row < displayRows.count else { return true }
        // 双击第二下时行往往已选中；须走系统 mouseDown 才能触发 doubleAction。
        if event.clickCount >= 2 { return true }
        let flags = event.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) { return true }
        // 普通单击自行处理选中，避免系统 mouseDown 进入框选追踪。
        return false
    }
    
    func handleRowMouseDown(row: Int, event: NSEvent) {
        if mouseDownHandledByDisclosureToggle { return }
        guard let tableView, row >= 0, row < displayRows.count else { return }
        guard event.clickCount == 1 else { return }
        let flags = event.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) { return }
        
        if !tableView.selectedRowIndexes.contains(row) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            syncSelectionFromTable()
            pendingRenameRow = -1
        } else if shouldBeginRenameOnMouseUp(row: row, pointInTable: tableView.convert(event.locationInWindow, from: nil)) {
            pendingRenameRow = row
        } else {
            pendingRenameRow = -1
        }
        refreshVisibleRowContentClip()
    }
    
    func didHandleMouseDown(_ event: NSEvent, row: Int) {
        if mouseDownHandledByDisclosureToggle { return }
        _ = row
        mouseDownEvent = event
    }
    
    func handleBlankMouseDown(_ event: NSEvent) {
        // 空白区按下时丢弃行上的按压状态，避免误触发文件拖拽。
        mouseDownEvent = nil
        mouseDownLocation = nil
        mouseDownRow = -1
        dragSessionActive = false
        
        blankMouseDownEvent = event
        blankDragSelecting = false
        
        if event.clickCount >= 2 {
            blankMouseDownEvent = nil
            interaction.onBlankDoubleClick()
            return
        }
        clearSelectionOnBlankClickIfNeeded()
        interaction.onBlankSingleClick()
    }
    
    /// 空白区单击：取消表格与 binding 中的选中高亮（右侧 padding 列、列表下方留白）。
    private func clearSelectionOnBlankClickIfNeeded() {
        guard let tableView else { return }
        let hasTableSelection = !tableView.selectedRowIndexes.isEmpty
        let hasBindingSelection = !(selectionGet?().isEmpty ?? true)
        guard hasTableSelection || hasBindingSelection else { return }
        
        if hasTableSelection {
            tableView.deselectAll(nil)
        }
        if hasBindingSelection {
            selectionSet?([])
        }
        refreshVisibleRowContentClip()
    }
    
    /// 空白区纵向框选；不触发文件拖放。
    func handleBlankMouseDragged(_ event: NSEvent) -> Bool {
        guard let startEvent = blankMouseDownEvent, let tableView else { return false }
        
        if !blankDragSelecting {
            let deltaX = event.locationInWindow.x - startEvent.locationInWindow.x
            let deltaY = event.locationInWindow.y - startEvent.locationInWindow.y
            guard hypot(deltaX, deltaY) >= dragThreshold else { return true }
            blankDragSelecting = true
            FileListContentInteractionNotifier.notifyDidBegin()
        }
        
        let startY = tableView.convert(startEvent.locationInWindow, from: nil).y
        let currentY = tableView.convert(event.locationInWindow, from: nil).y
        let rows = FileListInteractionCoordinator.rowsInVerticalRange(
            minY: startY,
            maxY: currentY,
            in: tableView
        )
        tableView.selectRowIndexes(rows, byExtendingSelection: false)
        syncSelectionFromTable()
        refreshVisibleRowContentClip()
        return true
    }
    
    func handleBlankMouseUp() {
        if blankDragSelecting || dragSessionActive {
            FileListContentInteractionNotifier.notifyDidEnd()
        }
        blankMouseDownEvent = nil
        blankDragSelecting = false
        mouseDownCanStartFileDrag = false
    }

    private func showBlankContextMenu(for event: NSEvent) {
        guard let tableView else { return }
        FileListInteractionCoordinator.showBlankContextMenu(
            for: event,
            on: tableView,
            actions: interaction.blankMenuActions
        )
    }

    func handleMouseDragged(_ event: NSEvent) -> Bool {
        if isRenaming { return false }
        if pendingRenameRow >= 0 {
            pendingRenameRow = -1
        }
        if handleBlankMouseDragged(event) { return true }

        guard !dragSessionActive,
              let start = mouseDownLocation,
              mouseDownEvent != nil,
              mouseDownCanStartFileDrag else { return false }

        let distance = hypot(
            event.locationInWindow.x - start.x,
            event.locationInWindow.y - start.y
        )
        guard distance >= dragThreshold else { return false }
        let row = mouseDownRow
        guard row >= 0, row < displayRows.count else { return false }
        guard let startEvent = mouseDownEvent else { return false }

        if let tableView, !tableView.selectedRowIndexes.contains(row) {
            let flags = mouseDownEvent?.modifierFlags ?? []
            if !flags.contains(.command) && !flags.contains(.shift) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                syncSelectionFromTable()
                refreshVisibleRowContentClip()
            }
        }

        dragSessionActive = true
        beginDrag(for: displayRows[row], rowIndex: row, startEvent: startEvent, dragEvent: event)
        return true
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        if isRenaming { return false }

        if event.keyCode == 36 || event.keyCode == 76, let tableView {
            let row = tableView.selectedRow
            guard row >= 0, row < displayRows.count else { return false }
            let flags = event.modifierFlags
            if flags.contains(.command), !flags.contains(.control), !flags.contains(.option) {
                onOpenRow?(FileListRowOpenIntent(row: displayRows[row], openInDetachedPreview: true))
                return true
            }
            guard !flags.contains(.command),
                  !flags.contains(.control),
                  !flags.contains(.option) else { return false }
            onOpenRow?(FileListRowOpenIntent(row: displayRows[row]))
            return true
        }
        
        let flags = event.modifierFlags
        if !flags.contains(.command), !flags.contains(.control), !flags.contains(.option) {
            if FileListInteractionCoordinator.handleQuickSearchKeys(
                event: event,
                interaction: interaction,
                effectiveSelectionIDs: { [weak self] in self?.effectiveSelectionIDs() ?? [] }
            ) {
                return true
            }
        }

        return FileListInteractionCoordinator.handleDeleteKey(event: event, interaction: interaction)
    }

    func handleKeyUp(_ event: NSEvent) -> Bool {
        if isRenaming { return false }
        return FileListInteractionCoordinator.handleQuickSearchKeyUp(event: event, interaction: interaction)
    }

    func handleRightMouseDown(_ event: NSEvent) {
        guard let tableView else { return }
        let point = tableView.convert(event.locationInWindow, from: nil)
        
        if isRenaming,
           let rowID = renamingRowID,
           let row = displayRows.firstIndex(where: { $0.id == rowID }),
           let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
               FileListColumnID.from(column: $0) == .name
           }),
           let cell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView,
           let field = renameField(in: cell),
           !field.isHidden {
            let pointInField = field.convert(point, from: tableView)
            if field.bounds.contains(pointInField) {
                tableView.window?.makeFirstResponder(field)
                field.rightMouseDown(with: event)
                return
            }
        }
        
        if isBlankInteractivePoint(point, in: tableView) {
            showBlankContextMenu(for: event)
            return
        }
        
        let row = tableView.row(at: point)
        
        if row >= 0, row < displayRows.count {
            if !tableView.selectedRowIndexes.contains(row) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                syncSelectionFromTable()
            }
            let clickedRow = displayRows[row]
            let selectedIDs = selectedRowIDs(from: tableView)
            if let menu = interaction.makeContextMenu(clickedRow, selectedIDs) {
                let fileURLs = FileListServiceURLs.from(rows: displayRows, selectedIDs: selectedIDs)
                interaction.popUpContextMenu(menu, event, tableView, fileURLs)
            }
            return
        }
        
        guard tableView.bounds.contains(point), interaction.blankMenuActions.isEnabled else { return }
        showBlankContextMenu(for: event)
    }
    
    // MARK: - Helpers
    
    func effectiveSelectionIDs() -> Set<String> {
        guard let tableView else {
            var ids = selectionGet?() ?? []
            ids.remove(FileListRow.parentDirectoryID)
            return ids
        }
        let tableSelectedIDs = Set(
            tableView.selectedRowIndexes.compactMap { row -> String? in
                guard row >= 0, row < displayRows.count else { return nil }
                let item = displayRows[row]
                guard !item.isParentDirectoryEntry else { return nil }
                return item.id
            }
        )
        return FileListInteractionCoordinator.tableEffectiveSelectionIDs(
            selectionGet: selectionGet,
            tableSelectedRowIDs: tableSelectedIDs
        )
    }
    
    private func selectedRowIDs(from tableView: NSTableView) -> Set<String> {
        Set(
            tableView.selectedRowIndexes.compactMap { row -> String? in
                guard row >= 0, row < displayRows.count else { return nil }
                return displayRows[row].id
            }
        )
    }
}
