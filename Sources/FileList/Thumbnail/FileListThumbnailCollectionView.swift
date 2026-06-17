import AppKit

final class FileListThumbnailCollectionView: NSCollectionView {
    weak var interactionController: FileListThumbnailController?
    
    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused {
            interactionController?.handleCollectionFocusChanged(true)
        }
        return focused
    }
    
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            interactionController?.handleCollectionFocusChanged(false)
        }
        return resigned
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let indexPath = indexPathForItem(at: point) {
            interactionController?.willHandleItemMouseDown(event, indexPath: indexPath)
            super.mouseDown(with: event)
            interactionController?.syncSelectionFromCollection()
            return
        }
        interactionController?.handleBlankMouseDown(event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if interactionController?.handleMouseDragged(event) == true {
            return
        }
        super.mouseDragged(with: event)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        interactionController?.handleRightMouseDown(event)
    }
    
    override func mouseUp(with event: NSEvent) {
        if event.clickCount >= 2,
           indexPathForItem(at: convert(event.locationInWindow, from: nil)) != nil {
            interactionController?.openSelectedRow()
        }
        interactionController?.handleBlankMouseUp()
        super.mouseUp(with: event)
        interactionController?.finishPointerInteractionIfNeeded()
    }
    
    override func keyDown(with event: NSEvent) {
        if interactionController?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}
