import AppKit

final class FileListTableHeaderView: NSTableHeaderView {
    weak var clickHandler: FileListTableController?
    
    /// 列分隔线左右各延伸的热区半宽（总宽约 10pt）；仅用于 hover 光标与按下判定。
    private let resizeHitRadius: CGFloat = 5
    private let sortClickMoveThreshold: CGFloat = 4
    
    private var pendingSortColumnID: FileListColumnID?
    private var mouseDownLocation: NSPoint?
    private var isColumnResizing = false
    private var resizingColumn: NSTableColumn?
    private var resizeSessionStartMouseX: CGFloat = 0
    private var resizeSessionStartWidth: CGFloat = 0
    private var resizeCursorTrackingArea: NSTrackingArea?
    private var columnResizeObserver: NSObjectProtocol?
    
    deinit {
        if let columnResizeObserver {
            NotificationCenter.default.removeObserver(columnResizeObserver)
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installColumnResizeObserverIfNeeded()
        refreshResizeCursorPresentation()
    }
    
    override func resetCursorRects() {
        // 不调用 super：系统会在列缘注册单向 resize 光标。
        discardCursorRects()
        for rect in columnResizeCursorRects() {
            addCursorRect(rect, cursor: .resizeLeftRight)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let resizeCursorTrackingArea {
            removeTrackingArea(resizeCursorTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        resizeCursorTrackingArea = area
    }
    
    override func layout() {
        super.layout()
        refreshResizeCursorPresentation()
    }
    
    override func cursorUpdate(with event: NSEvent) {
        guard !isColumnResizing else {
            NSCursor.resizeLeftRight.set()
            return
        }
        if updateResizeCursor(for: event) {
            return
        }
        NSCursor.arrow.set()
    }
    
    override func mouseMoved(with event: NSEvent) {
        guard !isColumnResizing else { return }
        _ = updateResizeCursor(for: event)
        super.mouseMoved(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        pendingSortColumnID = nil
        endColumnResizeSession()
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        
        guard let tableView, let point = mouseDownLocation else {
            super.mouseDown(with: event)
            return
        }
        
        if let target = resizeTarget(at: point) {
            beginColumnResizeSession(target: target, event: event)
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
        
        if isColumnResizing, let column = resizingColumn {
            applyColumnResize(for: column, event: event)
            NSCursor.resizeLeftRight.set()
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
        
        let wasResizing = isColumnResizing
        if wasResizing {
            finishColumnResizeSession()
            return
        }
        
        super.mouseUp(with: event)
        mouseDownLocation = nil
    }
    
    /// 在表头列分隔热区显示左右拖拽光标；返回是否已应用。
    func applyResizeCursor(at pointInHeader: NSPoint) -> Bool {
        guard !isColumnResizing, resizeTarget(at: pointInHeader) != nil else { return false }
        NSCursor.resizeLeftRight.set()
        return true
    }
    
    private func installColumnResizeObserverIfNeeded() {
        guard columnResizeObserver == nil, let tableView else { return }
        columnResizeObserver = NotificationCenter.default.addObserver(
            forName: NSTableView.columnDidResizeNotification,
            object: tableView,
            queue: .main
        ) { [weak self] _ in
            self?.refreshResizeCursorPresentation()
        }
    }
    
    private func beginColumnResizeSession(target: ColumnResizeTarget, event: NSEvent) {
        isColumnResizing = true
        resizingColumn = target.column
        resizeSessionStartMouseX = event.locationInWindow.x
        resizeSessionStartWidth = target.column.width
        NSCursor.resizeLeftRight.set()
    }
    
    private func applyColumnResize(for column: NSTableColumn, event: NSEvent) {
        let delta = event.locationInWindow.x - resizeSessionStartMouseX
        let minWidth = column.minWidth
        let maxWidth = column.maxWidth
        let newWidth = min(max(resizeSessionStartWidth + delta, minWidth), maxWidth)
        guard abs(column.width - newWidth) > 0.5 else { return }
        
        column.width = newWidth
        clickHandler?.invalidateVisibleRowHighlights()
        refreshResizeCursorPresentation()
    }
    
    private func finishColumnResizeSession() {
        let column = resizingColumn
        endColumnResizeSession()
        clickHandler?.invalidateVisibleRowHighlights()
        clickHandler?.scheduleWidthSave()
        clickHandler?.schedulePaddingColumnWidthAfterResize()
        if let column, let tableView {
            NotificationCenter.default.post(
                name: NSTableView.columnDidResizeNotification,
                object: tableView,
                userInfo: ["NSTableColumn": column]
            )
        }
        refreshResizeCursorPresentation()
    }
    
    private func endColumnResizeSession() {
        isColumnResizing = false
        resizingColumn = nil
        resizeSessionStartMouseX = 0
        resizeSessionStartWidth = 0
        mouseDownLocation = nil
    }
    
    private func refreshResizeCursorPresentation() {
        window?.invalidateCursorRects(for: self)
        resetCursorRects()
        guard !isColumnResizing, let window else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if bounds.contains(point), applyResizeCursor(at: point) {
            return
        }
        NSCursor.arrow.set()
    }
    
    @discardableResult
    private func updateResizeCursor(for event: NSEvent) -> Bool {
        let point = convert(event.locationInWindow, from: nil)
        return applyResizeCursor(at: point)
    }
    
    private func sortableColumnID(at point: NSPoint, tableView: NSTableView) -> FileListColumnID? {
        for index in 0..<tableView.tableColumns.count {
            let column = tableView.tableColumns[index]
            guard !FileListPaddingColumn.isPadding(column),
                  !column.isHidden,
                  let columnID = FileListColumnID.from(column: column) else { continue }
            
            let rect = headerRect(ofColumn: index)
            guard rect.width > resizeHitRadius * 2 else { continue }
            
            let titleRect = rect.insetBy(dx: resizeHitRadius, dy: 0)
            guard titleRect.contains(point) else { continue }
            return columnID
        }
        return nil
    }
    
    private struct ColumnResizeTarget {
        let column: NSTableColumn
        let dividerX: CGFloat
    }
    
    private func resizeTarget(at point: NSPoint) -> ColumnResizeTarget? {
        guard let snappedPoint = snappedResizeDividerPoint(for: point) else { return nil }
        return resizeTarget(forDividerAt: snappedPoint.x)
    }
    
    private func resizeTarget(forDividerAt dividerX: CGFloat) -> ColumnResizeTarget? {
        guard let tableView else { return nil }
        
        for index in 0..<tableView.tableColumns.count {
            let column = tableView.tableColumns[index]
            guard !FileListPaddingColumn.isPadding(column), !column.isHidden else { continue }
            
            let rect = headerRect(ofColumn: index)
            guard rect.width > 0 else { continue }
            
            if abs(dividerX - rect.maxX) <= 0.5 {
                return ColumnResizeTarget(column: column, dividerX: rect.maxX)
            }
            if index > 0, abs(dividerX - rect.minX) <= 0.5 {
                let leftColumn = tableView.tableColumns[index - 1]
                guard !FileListPaddingColumn.isPadding(leftColumn), !leftColumn.isHidden else { continue }
                return ColumnResizeTarget(column: leftColumn, dividerX: rect.minX)
            }
        }
        return nil
    }
    
    private func snappedResizeDividerPoint(for point: NSPoint) -> NSPoint? {
        guard let tableView else { return nil }
        
        var bestMatch: (point: NSPoint, distance: CGFloat)?
        for index in 0..<tableView.tableColumns.count {
            let column = tableView.tableColumns[index]
            guard !FileListPaddingColumn.isPadding(column), !column.isHidden else { continue }
            
            let rect = headerRect(ofColumn: index)
            guard rect.width > 0 else { continue }
            
            let dividerXs = index > 0 ? [rect.minX, rect.maxX] : [rect.maxX]
            for dividerX in dividerXs {
                let distance = abs(point.x - dividerX)
                guard distance <= resizeHitRadius else { continue }
                let snapped = NSPoint(x: dividerX, y: point.y)
                if let bestMatch, distance >= bestMatch.distance { continue }
                bestMatch = (snapped, distance)
            }
        }
        return bestMatch?.point
    }
    
    private func columnResizeCursorRects() -> [NSRect] {
        guard let tableView else { return [] }
        
        var rects: [NSRect] = []
        var seenDividerXs: Set<CGFloat> = []
        
        for index in 0..<tableView.tableColumns.count {
            let column = tableView.tableColumns[index]
            guard !FileListPaddingColumn.isPadding(column), !column.isHidden else { continue }
            
            let rect = headerRect(ofColumn: index)
            guard rect.width > 0 else { continue }
            
            let dividerXs = index > 0 ? [rect.minX, rect.maxX] : [rect.maxX]
            for dividerX in dividerXs {
                guard seenDividerXs.insert(dividerX).inserted else { continue }
                rects.append(NSRect(
                    x: dividerX - resizeHitRadius,
                    y: rect.minY,
                    width: resizeHitRadius * 2,
                    height: rect.height
                ))
            }
        }
        return rects
    }
}
