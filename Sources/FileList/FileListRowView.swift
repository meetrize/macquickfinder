import AppKit
import Foundation

final class FileListRowView: NSTableRowView {
    var isDropTargetRow = false {
        didSet {
            guard oldValue != isDropTargetRow else { return }
            needsDisplay = true
        }
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        guard isDropTargetRow else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        dirtyRect.fill()
    }
}
