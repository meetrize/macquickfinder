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
    
    // MARK: - NSDraggingDestination（比 delegate 更可靠，且能收到 exited 以清除高亮）
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        interactionController?.handleDraggingUpdated(sender) ?? []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        interactionController?.handleDraggingUpdated(sender) ?? []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard let sender, let controller = interactionController else {
            interactionController?.invalidateDropTarget()
            return
        }
        // 进入 cell 子视图时可能误触发 exited；若指针仍在网格内则保持高亮
        let point = convert(sender.draggingLocation, from: nil)
        if bounds.contains(point) {
            _ = controller.handleDraggingUpdated(sender)
            return
        }
        controller.invalidateDropTarget()
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        interactionController?.handleDraggingUpdated(sender) != []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        interactionController?.performDragOperation(sender) ?? false
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        interactionController?.clearDropHighlightVisualOnly()
    }
    
    // MARK: - Mouse
    
    private func resolvedIndexPath(at point: NSPoint) -> IndexPath? {
        if let indexPath = indexPathForItem(at: point) {
            return indexPath
        }
        for indexPath in indexPathsForVisibleItems() {
            guard let frame = layoutAttributesForItem(at: indexPath)?.frame else { continue }
            if frame.contains(point) {
                return indexPath
            }
        }
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let indexPath = resolvedIndexPath(at: point) {
            handleItemMouseDown(event, indexPath: indexPath)
            return
        }
        interactionController?.handleBlankMouseDown(event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        _ = interactionController?.handleMouseDragged(event)
        // 不透传 super，避免从文件项触发 NSCollectionView 框选；框选仅由空白区拖拽处理。
    }
    
    override func rightMouseDown(with event: NSEvent) {
        interactionController?.handleRightMouseDown(event)
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if resolvedIndexPath(at: point) != nil {
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
        interactionController?.clearBlankDragState()
        
        if event.clickCount >= 2 {
            interactionController?.willHandleItemMouseDown(event, indexPath: indexPath)
            interactionController?.skipNextItemMouseUp = true
            interactionController?.openRow(at: indexPath)
            interactionController?.finishPointerInteractionIfNeeded()
            return
        }
        
        interactionController?.willHandleItemMouseDown(event, indexPath: indexPath)
        if interactionController?.shouldUseDefaultItemMouseDown(for: indexPath, event: event) ?? true {
            interactionController?.usedSystemItemMouseDown = true
            super.mouseDown(with: event)
        } else {
            interactionController?.usedSystemItemMouseDown = false
            window?.makeFirstResponder(self)
            interactionController?.handleItemClickMouseDown(indexPath: indexPath, event: event)
        }
        interactionController?.didHandleItemMouseDown(event)
        interactionController?.syncSelectionFromCollection()
    }
    
    func handleItemMouseUp(_ event: NSEvent) {
        if interactionController?.skipNextItemMouseUp == true {
            interactionController?.skipNextItemMouseUp = false
            interactionController?.finishPointerInteractionIfNeeded()
            return
        }
        
        let point = convert(event.locationInWindow, from: nil)
        let indexPath = resolvedIndexPath(at: point)
        
        if interactionController?.usedSystemItemMouseDown == true {
            super.mouseUp(with: event)
        }
        
        if let indexPath {
            interactionController?.armRenameEligibleAfterClickIfNeeded(event, indexPath: indexPath)
        }
        interactionController?.finishPointerInteractionIfNeeded()
    }
}
