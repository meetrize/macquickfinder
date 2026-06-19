import AppKit
import Foundation

// MARK: - Interaction state

extension FileListTableController {
    // MARK: - Mouse & keyboard
    
    func handleTableFocusChanged(_ isFocused: Bool) {
        interaction.onTableFocusChanged(isFocused)
    }
    
    func willHandleMouseDown(_ event: NSEvent, row: Int, pointInTable: NSPoint) {
        mouseDownHandledByDisclosureToggle = false
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
        } else if shouldBeginRenameOnMouseUp(row: row) {
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
        let rows = rowsInVerticalRange(minY: startY, maxY: currentY, in: tableView)
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
    
    private func rowsInVerticalRange(
        minY: CGFloat,
        maxY: CGFloat,
        in tableView: NSTableView
    ) -> IndexSet {
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
        
        if let tableView, !tableView.selectedRowIndexes.contains(row) {
            let flags = mouseDownEvent?.modifierFlags ?? []
            if !flags.contains(.command) && !flags.contains(.shift) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                syncSelectionFromTable()
                refreshVisibleRowContentClip()
            }
        }
        
        dragSessionActive = true
        beginDrag(for: displayRows[row], rowIndex: row, event: event)
        return true
    }
    
    func handleKeyDown(_ event: NSEvent) -> Bool {
        if isRenaming { return false }
        
        // Return / Enter: 打开当前高亮行（与双击行为一致）。
        if event.keyCode == 36 || event.keyCode == 76 {
            guard !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.option),
                  let tableView
            else { return false }
            let row = tableView.selectedRow
            guard row >= 0, row < displayRows.count else { return false }
            onOpenRow?(displayRows[row])
            return true
        }
        
        let flags = event.modifierFlags
        if !flags.contains(.command), !flags.contains(.control), !flags.contains(.option) {
            // ESC: 关闭快速搜索
            if event.keyCode == 53 {
                interaction.onQuickSearchEscape()
                return true
            }
            // Delete / Forward Delete：优先编辑快速搜索词
            if event.keyCode == 51 || event.keyCode == 117 {
                if !interaction.quickSearchText.isEmpty {
                    interaction.onQuickSearchBackspace()
                    return true
                }
                // 无选中项时，Backspace 作为“后退到上一个目录”
                if event.keyCode == 51,
                   effectiveSelectionIDs().isEmpty,
                   interaction.canNavigateBack() {
                    interaction.onNavigateBack()
                    return true
                }
            }
            // 可见字符输入：唤起或追加快速搜索
            if let input = quickSearchInputCharacter(from: event) {
                interaction.onQuickSearchInput(input)
                return true
            }
        }
        
        guard event.keyCode == 51 || event.keyCode == 117 else { return false }
        guard !flags.contains(.command) else { return false }
        guard interaction.canDelete() else { return false }
        interaction.onDelete()
        return true
    }
    
    private func quickSearchInputCharacter(from event: NSEvent) -> String? {
        guard let input = event.charactersIgnoringModifiers, input.count == 1,
              let scalar = input.unicodeScalars.first
        else { return nil }
        
        // 排除空白、控制字符与 AppKit 特殊功能键私有区（如方向键/F 键等）。
        if CharacterSet.whitespacesAndNewlines.contains(scalar) { return nil }
        if CharacterSet.controlCharacters.contains(scalar) { return nil }
        if (0xF700...0xF8FF).contains(scalar.value) { return nil }
        
        // 仅文本字符触发快速搜索，功能键保持列表默认处理。
        if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
            return input
        }
        return nil
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
    
    // MARK: - Drag source
    
    func beginDrag(for row: FileListRow, rowIndex: Int, event: NSEvent) {
        guard let tableView else { return }
        let dragged = FileListDragSupport.draggedRows(
            for: row,
            in: displayRows,
            selection: effectiveSelectionIDs()
        )
        guard !dragged.isEmpty else { return }

        FileListContentInteractionNotifier.notifyDidBegin()
        
        let mousePoint = tableView.convert(event.locationInWindow, from: nil)
        var draggingItems: [NSDraggingItem] = []
        for (index, draggedRow) in dragged.enumerated() {
            let showLabel = dragged.count == 1 || draggedRow.id == row.id
            let ghost = FileListDragSupport.makeDragGhost(
                for: draggedRow.iconPath,
                name: draggedRow.name,
                showLabel: showLabel
            )
            let frame = FileListDragSupport.draggingFrame(
                at: mousePoint,
                ghostSize: ghost.size,
                index: index
            )
            let url = URL(fileURLWithPath: draggedRow.iconPath) as NSURL
            let draggingItem = NSDraggingItem(pasteboardWriter: url)
            draggingItem.setDraggingFrame(frame, contents: ghost.image)
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
    
    func setCurrentDirectoryDropHighlight(_ isTargeted: Bool) {
        interaction.onCurrentDirectoryDropHighlightChanged(isTargeted)
    }
    
    func clearAllDropHighlights() {
        clearDropHighlight()
        setCurrentDirectoryDropHighlight(false)
    }
    
    func resolvedDropTarget(
        in tableView: NSTableView,
        draggingInfo: NSDraggingInfo,
        urls: [URL]
    ) -> (row: Int?, destinationPath: String)? {
        let point = tableView.convert(draggingInfo.draggingLocation, from: nil)
        let row = tableView.row(at: point)
        
        if row >= 0, row < displayRows.count {
            let rowItem = displayRows[row]
            if let destinationPath = interaction.dropDestinationPath(rowItem),
               interaction.canAcceptDrop(destinationPath, urls) {
                return (row, destinationPath)
            }
        }
        
        if let currentPath = interaction.currentDirectoryDropPath,
           interaction.canAcceptDrop(currentPath, urls) {
            return (nil, currentPath)
        }
        
        return nil
    }
    
    func handleDraggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        guard let tableView else {
            clearAllDropHighlights()
            return []
        }
        
        let urls = FileListDragSupport.fileURLs(from: draggingInfo.draggingPasteboard)
        guard !urls.isEmpty else {
            clearAllDropHighlights()
            return []
        }
        
        guard let target = resolvedDropTarget(in: tableView, draggingInfo: draggingInfo, urls: urls) else {
            clearAllDropHighlights()
            return []
        }
        
        if let row = target.row {
            setDropHighlight(row: row)
            setCurrentDirectoryDropHighlight(false)
        } else {
            clearDropHighlight()
            setCurrentDirectoryDropHighlight(true)
        }
        
        return FileListDragSupport.shouldCopy(from: draggingInfo) ? .copy : .move
    }
    
    @discardableResult
    func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        guard let tableView else { return false }
        
        let urls = FileListDragSupport.fileURLs(from: draggingInfo.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        
        guard let target = resolvedDropTarget(in: tableView, draggingInfo: draggingInfo, urls: urls) else {
            return false
        }
        
        let copy = FileListDragSupport.shouldCopy(from: draggingInfo)
        clearAllDropHighlights()
        interaction.performDrop(target.destinationPath, urls, copy)
        return true
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
        FileListContentInteractionNotifier.notifyDidEnd()
        mouseDownLocation = nil
        mouseDownEvent = nil
        mouseDownCanStartFileDrag = false
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
        proposedRow row: UnsafeMutablePointer<Int>,
        proposedDropOperation dropOperation: UnsafeMutablePointer<NSTableView.DropOperation>
    ) -> NSDragOperation {
        let operation = handleDraggingUpdated(info)
        guard operation != [] else { return [] }
        
        let point = tableView.convert(info.draggingLocation, from: nil)
        let targetRow = tableView.row(at: point)
        if targetRow >= 0,
           targetRow < displayRows.count,
           interaction.dropDestinationPath(displayRows[targetRow]) != nil {
            row.pointee = targetRow
        } else {
            row.pointee = -1
        }
        dropOperation.pointee = .on
        return operation
    }
    
    public func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        performDragOperation(info)
    }
    
    public func tableView(
        _ tableView: NSTableView,
        draggingSession session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        clearAllDropHighlights()
    }
}
