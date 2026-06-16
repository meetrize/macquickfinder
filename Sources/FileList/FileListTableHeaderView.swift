import AppKit

final class FileListTableHeaderView: NSTableHeaderView {
    weak var clickHandler: FileListTableController?
    
    override func mouseDown(with event: NSEvent) {
        guard let tableView, let clickHandler else {
            super.mouseDown(with: event)
            return
        }
        
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else {
            super.mouseDown(with: event)
            return
        }
        
        let columnIndex = tableView.column(at: point)
        guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else {
            super.mouseDown(with: event)
            return
        }
        
        if event.modifierFlags.contains(.control) || event.type == .rightMouseDown {
            super.mouseDown(with: event)
            return
        }
        
        if let columnID = FileListColumnID.from(column: tableView.tableColumns[columnIndex]) {
            clickHandler.handleHeaderSortClick(columnID: columnID)
        }
    }
}
