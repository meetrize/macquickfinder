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
            handleItemMouseDown(event, indexPath: indexPath)
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
        let point = convert(event.locationInWindow, from: nil)
        if indexPathForItem(at: point) != nil {
            handleItemMouseUp(event)
            return
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
    
    func handleItemMouseDown(_ event: NSEvent, indexPath: IndexPath) {
        interactionController?.willHandleItemMouseDown(event, indexPath: indexPath)
        super.mouseDown(with: event)
        interactionController?.syncSelectionFromCollection()
    }
    
    func handleItemMouseUp(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let indexPath = indexPathForItem(at: point)
        let willRename = interactionController?.pendingRenameIndexPath != nil
        
        if event.clickCount >= 2, indexPath != nil, !willRename {
            interactionController?.openSelectedRow()
        }
        super.mouseUp(with: event)
        if let indexPath {
            interactionController?.armRenameEligibleAfterClickIfNeeded(event, indexPath: indexPath)
        }
        interactionController?.finishPointerInteractionIfNeeded()
    }
    
    func handleItemMouseDragged(_ event: NSEvent) {
        if interactionController?.handleMouseDragged(event) == true {
            return
        }
        super.mouseDragged(with: event)
    }
}
