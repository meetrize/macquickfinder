import AppKit

final class FileListTableHeaderView: NSTableHeaderView {
    weak var clickHandler: FileListTableController?
    
    /// 列缘留给系统拖拽调宽的热区宽度；中间区域单击用于排序。
    private let resizeZoneWidth: CGFloat = 5
    private let sortClickMoveThreshold: CGFloat = 4
    
    private var pendingSortColumnID: FileListColumnID?
    private var mouseDownLocation: NSPoint?
    
    override func mouseDown(with event: NSEvent) {
        pendingSortColumnID = nil
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        
        guard let tableView, let point = mouseDownLocation else {
            super.mouseDown(with: event)
            return
        }
        
        // 分隔条区域：交给系统处理列宽拖拽。
        if isOnColumnResizeDivider(at: point) {
            super.mouseDown(with: event)
            return
        }
        
        // 标题中间区域：自行处理排序，不调用 super，避免系统吞掉点击。
        if event.type == .leftMouseDown,
           !event.modifierFlags.contains(.control),
           bounds.contains(point),
           let columnID = sortableColumnID(at: point, tableView: tableView) {
            pendingSortColumnID = columnID
            return
        }
        
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if pendingSortColumnID != nil {
            if let start = mouseDownLocation {
                let current = convert(event.locationInWindow, from: nil)
                if hypot(current.x - start.x, current.y - start.y) >= sortClickMoveThreshold {
                    pendingSortColumnID = nil
                }
            }
            return
        }
        super.mouseDragged(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        if let columnID = pendingSortColumnID {
            pendingSortColumnID = nil
            mouseDownLocation = nil
            clickHandler?.handleHeaderSortClick(columnID: columnID)
            return
        }
        super.mouseUp(with: event)
        mouseDownLocation = nil
    }
    
    private func sortableColumnID(at point: NSPoint, tableView: NSTableView) -> FileListColumnID? {
        for index in 0..<tableView.tableColumns.count {
            let column = tableView.tableColumns[index]
            guard !FileListPaddingColumn.isPadding(column),
                  !column.isHidden,
                  let columnID = FileListColumnID.from(column: column) else { continue }
            
            let rect = headerRect(ofColumn: index)
            guard rect.width > resizeZoneWidth * 2 else { continue }
            
            let titleRect = rect.insetBy(dx: resizeZoneWidth, dy: 0)
            guard titleRect.contains(point) else { continue }
            return columnID
        }
        return nil
    }
    
    private func isOnColumnResizeDivider(at point: NSPoint) -> Bool {
        guard let tableView else { return false }
        
        for index in 0..<tableView.tableColumns.count {
            let column = tableView.tableColumns[index]
            guard !FileListPaddingColumn.isPadding(column), !column.isHidden else { continue }
            
            let rect = headerRect(ofColumn: index)
            guard rect.width > 0 else { continue }
            
            if point.x >= rect.maxX - resizeZoneWidth, point.x <= rect.maxX {
                return true
            }
            if index > 0, point.x >= rect.minX, point.x <= rect.minX + resizeZoneWidth {
                return true
            }
        }
        return false
    }
}
