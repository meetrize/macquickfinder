import AppKit

final class FileListTableHeaderView: NSTableHeaderView {
    weak var clickHandler: FileListTableController?
    
    /// 列左右边缘留给系统拖拽调宽的热区，中间区域单击用于排序。
    private let resizeZoneWidth: CGFloat = 12
    private let sortClickMoveThreshold: CGFloat = 3
    
    private var pendingSortColumnID: FileListColumnID?
    private var mouseDownLocation: NSPoint?
    
    override func mouseDown(with event: NSEvent) {
        pendingSortColumnID = nil
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        
        if let tableView,
           event.type == .leftMouseDown,
           !event.modifierFlags.contains(.control),
           let point = mouseDownLocation,
           bounds.contains(point),
           let columnID = sortableColumnID(at: point, tableView: tableView) {
            pendingSortColumnID = columnID
        }
        
        // 必须交给 super，系统才能处理列分隔条拖拽。
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if let start = mouseDownLocation {
            let current = convert(event.locationInWindow, from: nil)
            if hypot(current.x - start.x, current.y - start.y) >= sortClickMoveThreshold {
                pendingSortColumnID = nil
            }
        }
        super.mouseDragged(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        if let columnID = pendingSortColumnID {
            clickHandler?.handleHeaderSortClick(columnID: columnID)
        }
        pendingSortColumnID = nil
        mouseDownLocation = nil
    }
    
    private func sortableColumnID(at point: NSPoint, tableView: NSTableView) -> FileListColumnID? {
        guard !isOnColumnResizeDivider(at: point, tableView: tableView) else { return nil }
        
        let columnIndex = tableView.column(at: point)
        guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return nil }
        
        let column = tableView.tableColumns[columnIndex]
        guard !FileListPaddingColumn.isPadding(column),
              let columnID = FileListColumnID.from(column: column) else { return nil }
        
        let rect = columnRect(at: columnIndex, tableView: tableView)
        guard rect.width > resizeZoneWidth * 2 else { return nil }
        
        let titleRect = rect.insetBy(dx: resizeZoneWidth, dy: 0)
        guard titleRect.contains(point) else { return nil }
        
        return columnID
    }
    
    private func isOnColumnResizeDivider(at point: NSPoint, tableView: NSTableView) -> Bool {
        for index in 0..<tableView.tableColumns.count {
            let column = tableView.tableColumns[index]
            guard !FileListPaddingColumn.isPadding(column), !column.isHidden else { continue }
            
            let columnRect = columnRect(at: index, tableView: tableView)
            guard columnRect.width > 0 else { continue }
            
            // 列右缘：拖动此列与下一列之间的分隔条
            if point.x >= columnRect.maxX - resizeZoneWidth,
               point.x <= columnRect.maxX + resizeZoneWidth {
                return true
            }
            
            // 列左缘：拖动与上一列之间的分隔条（首列除外）
            if index > 0,
               point.x >= columnRect.minX - resizeZoneWidth,
               point.x <= columnRect.minX + resizeZoneWidth {
                return true
            }
        }
        return false
    }
    
    private func columnRect(at index: Int, tableView: NSTableView) -> NSRect {
        var originX = bounds.minX
        let spacing = tableView.intercellSpacing.width
        
        for i in 0..<index {
            let column = tableView.tableColumns[i]
            guard !column.isHidden else { continue }
            if i > 0 || originX > bounds.minX { originX += spacing }
            originX += column.width
        }
        
        let column = tableView.tableColumns[index]
        guard !column.isHidden else { return .zero }
        return NSRect(x: originX, y: bounds.minY, width: column.width, height: bounds.height)
    }
}
