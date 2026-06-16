import AppKit
import Foundation

final class FileListRowView: NSTableRowView {
    var contentBackgroundMaxX: CGFloat?
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
        guard let contentBackgroundMaxX, contentBackgroundMaxX < bounds.maxX else {
            return dirtyRect
        }
        let contentRect = NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: max(0, contentBackgroundMaxX - bounds.minX),
            height: bounds.height
        )
        return NSIntersectionRect(dirtyRect, contentRect)
    }
}
