import AppKit
import Foundation

final class FileListRowView: NSTableRowView {
    /// 缓存值；绘制时优先根据表格列布局实时计算，保证列宽拖拽中高亮同步。
    var contentBackgroundMaxX: CGFloat? {
        didSet {
            guard oldValue != contentBackgroundMaxX else { return }
            needsDisplay = true
        }
    }
    var isDropTargetRow = false {
        didSet {
            guard oldValue != isDropTargetRow else { return }
            needsDisplay = true
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        if #available(macOS 11.0, *) {
            selectionHighlightStyle = .none
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        let clipped = contentClip(of: dirtyRect)
        guard !clipped.isEmpty else { return }
        super.drawBackground(in: clipped)
        
        guard isDropTargetRow else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        clipped.fill()
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let clipped = contentClip(of: dirtyRect)
        guard !clipped.isEmpty else { return }
        let color = isEmphasized
            ? NSColor.selectedContentBackgroundColor
            : NSColor.unemphasizedSelectedContentBackgroundColor
        color.setFill()
        clipped.fill()
    }
    
    private func contentClip(of dirtyRect: NSRect) -> NSRect {
        guard let maxX = resolvedContentMaxX(), maxX < bounds.maxX else {
            return dirtyRect
        }
        let contentRect = NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: max(0, maxX - bounds.minX),
            height: bounds.height
        )
        return NSIntersectionRect(dirtyRect, contentRect)
    }
    
    private func resolvedContentMaxX() -> CGFloat? {
        guard let tableView = enclosingTableView() else {
            return contentBackgroundMaxX
        }
        
        var lastDataColumnIndex: Int?
        for (index, column) in tableView.tableColumns.enumerated() {
            guard !FileListPaddingColumn.isPadding(column), !column.isHidden else { continue }
            lastDataColumnIndex = index
        }
        guard let lastDataColumnIndex else { return contentBackgroundMaxX }
        
        let maxXInTable = tableView.rect(ofColumn: lastDataColumnIndex).maxX
        return convert(NSPoint(x: maxXInTable, y: 0), from: tableView).x
    }
    
    private func enclosingTableView() -> NSTableView? {
        var view: NSView? = self
        while let current = view {
            if let tableView = current as? NSTableView {
                return tableView
            }
            view = current.superview
        }
        return nil
    }
}
