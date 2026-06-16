import AppKit

final class FileListTableView: NSTableView {
    weak var interactionController: FileListTableController?
    
    override func rightMouseDown(with event: NSEvent) {
        interactionController?.handleRightMouseDown(event)
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        
        interactionController?.willHandleMouseDown(event, row: row)
        
        if interactionController?.shouldUseDefaultMouseDown(for: row, event: event) ?? true {
            super.mouseDown(with: event)
        } else {
            window?.makeFirstResponder(self)
        }
        
        interactionController?.didHandleMouseDown(event, row: row)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if interactionController?.handleMouseDragged(event) == true {
            return
        }
        super.mouseDragged(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        if interactionController?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}
