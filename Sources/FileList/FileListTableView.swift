import AppKit

final class FileListTableView: NSTableView {
    weak var interactionController: FileListTableController?
    weak var servicesRequestor: (any FileListServicesMenuRequestor)?

    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?
    ) -> Any? {
        if let requestor = servicesRequestor?.validRequestor(
            forSendType: sendType,
            returnType: returnType
        ) {
            return requestor
        }
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }

    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused {
            interactionController?.handleTableFocusChanged(true)
        }
        return focused
    }
    
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            interactionController?.handleTableFocusChanged(false)
        }
        return resigned
    }
    
    override func rightMouseDown(with event: NSEvent) {
        interactionController?.handleRightMouseDown(event)
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        
        if interactionController?.isBlankInteractivePoint(point, in: self) == true {
            interactionController?.handleBlankMouseDown(event)
            return
        }
        
        interactionController?.handleBlankMouseUp()
        interactionController?.willHandleMouseDown(event, row: row, pointInTable: point)
        if interactionController?.mouseDownHandledByDisclosureToggle == true {
            return
        }
        
        if interactionController?.shouldUseDefaultMouseDown(for: row, event: event) ?? true {
            super.mouseDown(with: event)
        } else {
            window?.makeFirstResponder(self)
            interactionController?.handleRowMouseDown(row: row, event: event)
        }
        
        interactionController?.didHandleMouseDown(event, row: row)
    }
    
    override func mouseDragged(with event: NSEvent) {
        _ = interactionController?.handleMouseDragged(event)
        // 不透传 super，避免从文件行触发系统框选；框选仅由空白区拖拽处理。
    }
    
    override func mouseUp(with event: NSEvent) {
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
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        interactionController?.schedulePaddingColumnLayout()
    }
    
    // MARK: - NSDraggingDestination（比仅依赖 delegate 更可靠，跨窗口拖放尤其需要）
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        interactionController?.handleDraggingUpdated(sender) ?? []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        interactionController?.handleDraggingUpdated(sender) ?? []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        interactionController?.clearAllDropHighlights()
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        interactionController?.handleDraggingUpdated(sender) != []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        interactionController?.performDragOperation(sender) ?? false
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        interactionController?.clearAllDropHighlights()
    }
}
