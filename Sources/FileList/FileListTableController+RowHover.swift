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
        let hoveredRow = isValidHoverRow(row, in: tableView) ? row : nil
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

    /// 选中变更 / layout 同步路径里不要立刻碰 `rowView(atRow:)`，否则可能触发 AppKit 越界异常。
    func scheduleRefreshRowHoverHighlightFromCurrentMouseLocation() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshRowHoverHighlightFromCurrentMouseLocation()
        }
    }

    func clearRowHoverHighlight() {
        setRowHoverHighlight(nil)
    }

    /// 列表 reload / 行数变化前丢弃悬停行号，避免用过期 index 访问 NSTableView。
    func invalidateRowHoverHighlightState() {
        hoverHighlightRow = nil
    }

    private func setRowHoverHighlight(_ row: Int?) {
        guard let tableView else {
            hoverHighlightRow = row
            return
        }
        setRowHoverHighlight(row, in: tableView)
    }

    private func setRowHoverHighlight(_ row: Int?, in tableView: NSTableView) {
        let safeRow = row.flatMap { isValidHoverRow($0, in: tableView) ? $0 : nil }
        guard hoverHighlightRow != safeRow else { return }
        let previous = hoverHighlightRow
        hoverHighlightRow = safeRow

        if let previous {
            applyRowHoverHighlight(false, row: previous, in: tableView)
        }
        if let safeRow {
            applyRowHoverHighlight(true, row: safeRow, in: tableView)
        }
    }

    func syncRowHoverHighlight(forRow row: Int, rowView: FileListRowView) {
        let isHovered = rowHoverHighlightEnabled
            && row == hoverHighlightRow
            && !(tableView?.selectedRowIndexes.contains(row) ?? false)
        rowView.isHoverHighlighted = isHovered
    }

    private func isValidHoverRow(_ row: Int, in tableView: NSTableView) -> Bool {
        row >= 0
            && row < displayRows.count
            && row < tableView.numberOfRows
    }

    private func applyRowHoverHighlight(_ highlighted: Bool, row: Int, in tableView: NSTableView) {
        // `rowView(atRow:)` 在越界时会抛 ObjC 异常并直接崩进程，必须先校验 numberOfRows。
        guard isValidHoverRow(row, in: tableView) else { return }
        guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? FileListRowView else {
            return
        }
        let isHovered = highlighted
            && rowHoverHighlightEnabled
            && !tableView.selectedRowIndexes.contains(row)
        rowView.isHoverHighlighted = isHovered
    }
}
