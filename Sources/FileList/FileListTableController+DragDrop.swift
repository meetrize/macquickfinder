import AppKit
import Foundation

// MARK: - Drag source

extension FileListTableController {
    func beginDrag(for row: FileListRow, rowIndex: Int, startEvent: NSEvent, dragEvent: NSEvent) {
        guard let tableView else { return }
        let ghostAnchor = tableView.convert(dragEvent.locationInWindow, from: nil)
        _ = FileListDragDropSupport.beginFileDrag(
            on: tableView,
            row: row,
            displayRows: displayRows,
            selection: effectiveSelectionIDs(),
            startEvent: startEvent,
            ghostAnchorInView: ghostAnchor,
            source: self
        )
        _ = rowIndex
    }
}

// MARK: - Drop highlight

extension FileListTableController {
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

    private func applyDropHighlight(_ highlight: FileListDragDropSupport.DropHighlight) {
        switch highlight {
        case .itemRow(let row):
            setDropHighlight(row: row)
            setCurrentDirectoryDropHighlight(false)
        case .currentDirectory:
            clearDropHighlight()
            setCurrentDirectoryDropHighlight(true)
        case .none:
            clearAllDropHighlights()
        }
    }

    func handleDraggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        guard let tableView else {
            clearAllDropHighlights()
            return []
        }

        let point = tableView.convert(draggingInfo.draggingLocation, from: nil)
        let row = tableView.row(at: point)
        let rowIndex = row >= 0 ? row : nil

        guard let evaluation = FileListDragDropSupport.evaluateDrop(
            displayRows: displayRows,
            rowIndex: rowIndex,
            interaction: interaction,
            draggingInfo: draggingInfo
        ) else {
            clearAllDropHighlights()
            return []
        }

        applyDropHighlight(evaluation.highlight)
        return evaluation.operation
    }

    @discardableResult
    func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        guard let tableView else { return false }

        let point = tableView.convert(draggingInfo.draggingLocation, from: nil)
        let row = tableView.row(at: point)
        let rowIndex = row >= 0 ? row : nil

        guard let evaluation = FileListDragDropSupport.evaluateDrop(
            displayRows: displayRows,
            rowIndex: rowIndex,
            interaction: interaction,
            draggingInfo: draggingInfo
        ) else {
            return false
        }

        clearAllDropHighlights()
        FileListDragDropSupport.performAcceptedDrop(
            destinationPath: evaluation.destinationPath,
            urls: evaluation.urls,
            draggingInfo: draggingInfo,
            interaction: interaction
        )
        return true
    }
}

// MARK: - NSDraggingSource

extension FileListTableController: NSDraggingSource {
    public func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        FileListDragDropSupport.sourceOperationMask(for: context)
    }

    public func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        noteDragSessionEnded(performingDrop: operation != [])
        finishPointerInteractionIfNeeded()
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
        syncRowHoverHighlight(forRow: row, rowView: rowView)
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
