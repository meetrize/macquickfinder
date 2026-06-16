import AppKit
import Foundation

// MARK: - Interaction state

extension FileListTableController {
    // MARK: - Mouse & keyboard
    
    func willHandleMouseDown(_ event: NSEvent, row: Int) {
        mouseDownRow = row
        mouseDownLocation = event.locationInWindow
        mouseDownEvent = event
        dragSessionActive = false
    }
    
    func shouldUseDefaultMouseDown(for row: Int, event: NSEvent) -> Bool {
        guard row >= 0, row < displayRows.count else { return true }
        // 双击第二下时行往往已选中；须走系统 mouseDown 才能触发 doubleAction。
        if event.clickCount >= 2 { return true }
        let flags = event.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) { return true }
        // 以表格实际选中状态为准；binding 可能尚未同步，误用 effectiveSelectionIDs 会吞掉首次点击。
        guard let tableView else { return true }
        return !tableView.selectedRowIndexes.contains(row)
    }
    
    func didHandleMouseDown(_ event: NSEvent, row: Int) {
        _ = row
        mouseDownEvent = event
    }
    
    func handleBlankMouseDown(_ event: NSEvent) {
        blankMouseDownEvent = event
        blankIsDragSelecting = false
        
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
    
    func handleBlankMouseDragged(_ event: NSEvent) -> Bool {
        guard let tableView, let blankMouseDownEvent else { return false }
        if !blankIsDragSelecting {
            let deltaX = event.locationInWindow.x - blankMouseDownEvent.locationInWindow.x
            let deltaY = event.locationInWindow.y - blankMouseDownEvent.locationInWindow.y
            guard hypot(deltaX, deltaY) >= dragThreshold else { return false }
            blankIsDragSelecting = true
        }
        
        let startY = tableView.convert(blankMouseDownEvent.locationInWindow, from: nil).y
        let currentY = tableView.convert(event.locationInWindow, from: nil).y
        let rows = rowsInVerticalRange(minY: startY, maxY: currentY, tableView: tableView)
        var indexes = IndexSet()
        for row in rows where row >= 0 && row < displayRows.count {
            indexes.insert(row)
        }
        if tableView.selectedRowIndexes != indexes {
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            syncSelectionFromTable()
        }
        return true
    }
    
    func handleBlankMouseUp() {
        blankMouseDownEvent = nil
        blankIsDragSelecting = false
    }
    
    private func rowsInVerticalRange(minY: CGFloat, maxY: CGFloat, tableView: NSTableView) -> IndexSet {
        let lower = min(minY, maxY)
        let upper = max(minY, maxY)
        var rows = IndexSet()
        for row in 0..<tableView.numberOfRows {
            let rowRect = tableView.rect(ofRow: row)
            if rowRect.maxY >= lower && rowRect.minY <= upper {
                rows.insert(row)
            }
        }
        return rows
    }
    
    private func showBlankContextMenu(for event: NSEvent) {
        guard let tableView, interaction.blankMenuActions.isEnabled else { return }
        let controller = FileListBlankMenuController(actions: interaction.blankMenuActions)
        let menu = controller.makeMenu()
        guard !menu.items.isEmpty else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: tableView)
    }
    
    func handleMouseDragged(_ event: NSEvent) -> Bool {
        if handleBlankMouseDragged(event) { return true }
        
        guard !dragSessionActive,
              let start = mouseDownLocation,
              mouseDownEvent != nil else { return false }
        
        let distance = hypot(
            event.locationInWindow.x - start.x,
            event.locationInWindow.y - start.y
        )
        guard distance >= dragThreshold else { return false }
        let row = mouseDownRow
        guard row >= 0, row < displayRows.count else { return false }
        
        dragSessionActive = true
        beginDrag(for: displayRows[row], rowIndex: row, event: event)
        return true
    }
    
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard event.keyCode == 51 || event.keyCode == 117 else { return false }
        guard !event.modifierFlags.contains(.command) else { return false }
        guard interaction.canDelete() else { return false }
        interaction.onDelete()
        return true
    }
    
    func handleRightMouseDown(_ event: NSEvent) {
        guard let tableView else { return }
        let point = tableView.convert(event.locationInWindow, from: nil)
        
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
                NSMenu.popUpContextMenu(menu, with: event, for: tableView)
            }
            return
        }
        
        guard tableView.bounds.contains(point), interaction.blankMenuActions.isEnabled else { return }
        showBlankContextMenu(for: event)
    }
    
    // MARK: - Drag source
    
    func beginDrag(for row: FileListRow, rowIndex: Int, event: NSEvent) {
        guard let tableView else { return }
        let dragged = FileListDragSupport.draggedRows(
            for: row,
            in: displayRows,
            selection: effectiveSelectionIDs()
        )
        guard !dragged.isEmpty else { return }
        
        let mousePoint = tableView.convert(event.locationInWindow, from: nil)
        var draggingItems: [NSDraggingItem] = []
        for (index, draggedRow) in dragged.enumerated() {
            let frame = FileListDragSupport.iconFrame(at: mousePoint, index: index)
            let url = URL(fileURLWithPath: draggedRow.iconPath) as NSURL
            let ghostImage = FileListDragSupport.ghostImage(for: draggedRow.iconPath)
            let draggingItem = NSDraggingItem(pasteboardWriter: url)
            draggingItem.setDraggingFrame(frame, contents: ghostImage)
            draggingItems.append(draggingItem)
        }
        
        let session = tableView.beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = dragged.count > 1 ? .pile : .none
    }
    
    // MARK: - Drop highlight
    
    func setDropHighlight(row: Int?) {
        guard dropHighlightRow != row else { return }
        let previous = dropHighlightRow
        dropHighlightRow = row
        
        if let previous, let tableView {
            (tableView.rowView(atRow: previous, makeIfNecessary: false) as? FileListRowView)?
                .isDropTargetRow = false
        }
        if let row, let tableView {
            (tableView.rowView(atRow: row, makeIfNecessary: true) as? FileListRowView)?
                .isDropTargetRow = true
        }
    }
    
    func clearDropHighlight() {
        setDropHighlight(row: nil)
    }
    
    // MARK: - Helpers
    
    func effectiveSelectionIDs() -> Set<String> {
        var ids = selectionGet?() ?? []
        ids.remove(FileListRow.parentDirectoryID)
        guard let tableView else { return ids }
        for row in tableView.selectedRowIndexes {
            guard row >= 0, row < displayRows.count else { continue }
            let item = displayRows[row]
            guard !item.isParentDirectoryEntry else { continue }
            ids.insert(item.id)
        }
        return ids
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

// MARK: - NSDraggingSource

extension FileListTableController: NSDraggingSource {
    public func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        if FileListDragSupport.shouldCopyFromCurrentEvent() {
            return .copy
        }
        switch context {
        case .withinApplication:
            return .move
        default:
            return .move
        }
    }
    
    public func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        dragSessionActive = false
        mouseDownLocation = nil
        mouseDownEvent = nil
        finishPointerInteractionIfNeeded()
        if operation != [] {
            DispatchQueue.main.async { [weak self] in
                self?.interaction.onDragEnded()
            }
        }
    }
}

// MARK: - Drop destination (NSTableViewDelegate)

extension FileListTableController {
    public func tableView(
        _ tableView: NSTableView,
        rowViewForRow row: Int
    ) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("FileListRowView")
        let rowView: FileListRowView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? FileListRowView {
            rowView = reused
        } else {
            rowView = FileListRowView()
            rowView.identifier = identifier
        }
        if #available(macOS 11.0, *) {
            rowView.selectionHighlightStyle = .none
        }
        rowView.isDropTargetRow = row == dropHighlightRow
        rowView.contentBackgroundMaxX = dataColumnsTrailingX(in: tableView)
        return rowView
    }
    
    public func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        let urls = FileListDragSupport.fileURLs(from: info.draggingPasteboard)
        guard !urls.isEmpty else {
            clearDropHighlight()
            return []
        }
        
        let point = tableView.convert(info.draggingLocation, from: nil)
        let targetRow = row >= 0 ? row : tableView.row(at: point)
        guard targetRow >= 0, targetRow < displayRows.count else {
            clearDropHighlight()
            return []
        }
        
        let rowItem = displayRows[targetRow]
        guard let destinationPath = interaction.dropDestinationPath(rowItem),
              interaction.canAcceptDrop(destinationPath, urls) else {
            clearDropHighlight()
            return []
        }
        
        setDropHighlight(row: targetRow)
        return FileListDragSupport.shouldCopyFromCurrentEvent() ? .copy : .move
    }
    
    public func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        clearDropHighlight()
        let urls = FileListDragSupport.fileURLs(from: info.draggingPasteboard)
        guard !urls.isEmpty, row >= 0, row < displayRows.count else { return false }
        guard let destinationPath = interaction.dropDestinationPath(displayRows[row]) else { return false }
        
        let copy = FileListDragSupport.shouldCopyFromCurrentEvent()
        interaction.performDrop(destinationPath, urls, copy)
        return true
    }
    
    public func tableView(
        _ tableView: NSTableView,
        draggingSession session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        clearDropHighlight()
    }
}
