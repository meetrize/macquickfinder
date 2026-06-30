import AppKit
import Foundation

extension FileListTableController {
    var rowHoverHighlightEnabled: Bool {
        get { _rowHoverHighlightEnabled }
        set {
            let changed = _rowHoverHighlightEnabled != newValue
            _rowHoverHighlightEnabled = newValue
            guard changed else { return }
            if !newValue {
                clearRowHoverHighlight()
            }
            (tableView as? FileListTableView)?.updateRowHoverTrackingEnabled(newValue)
        }
    }

    func updateRowHover(at point: NSPoint, in tableView: NSTableView) {
        guard rowHoverHighlightEnabled else {
            clearRowHoverHighlight()
            return
        }
        let row = tableView.row(at: point)
        let hoveredRow = (row >= 0 && row < displayRows.count) ? row : nil
        setRowHoverHighlight(hoveredRow, in: tableView)
    }

    func refreshRowHoverHighlightFromCurrentMouseLocation() {
        guard rowHoverHighlightEnabled, let tableView, let window = tableView.window else {
            clearRowHoverHighlight()
            return
        }
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let point = tableView.convert(mouseLocation, from: nil)
        guard tableView.bounds.contains(point) else {
            clearRowHoverHighlight()
            return
        }
        updateRowHover(at: point, in: tableView)
    }

    func clearRowHoverHighlight() {
        setRowHoverHighlight(nil)
    }

    private func setRowHoverHighlight(_ row: Int?) {
        guard let tableView else {
            hoverHighlightRow = row
            return
        }
        setRowHoverHighlight(row, in: tableView)
    }

    private func setRowHoverHighlight(_ row: Int?, in tableView: NSTableView) {
        guard hoverHighlightRow != row else { return }
        let previous = hoverHighlightRow
        hoverHighlightRow = row

        if let previous {
            applyRowHoverHighlight(false, row: previous, in: tableView)
        }
        if let row {
            applyRowHoverHighlight(true, row: row, in: tableView)
        }
    }

    func syncRowHoverHighlight(forRow row: Int, rowView: FileListRowView) {
        let isHovered = rowHoverHighlightEnabled
            && row == hoverHighlightRow
            && !(tableView?.selectedRowIndexes.contains(row) ?? false)
        rowView.isHoverHighlighted = isHovered
    }

    private func applyRowHoverHighlight(_ highlighted: Bool, row: Int, in tableView: NSTableView) {
        guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? FileListRowView else {
            return
        }
        let isHovered = highlighted
            && rowHoverHighlightEnabled
            && !tableView.selectedRowIndexes.contains(row)
        rowView.isHoverHighlighted = isHovered
    }
}
