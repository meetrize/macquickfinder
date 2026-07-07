import AppKit

final class FileListTableView: NSTableView {
    weak var interactionController: FileListTableController?
    weak var servicesRequestor: (any FileListServicesMenuRequestor)?

    private var rowHoverTrackingArea: NSTrackingArea?
    private var rowHoverTrackingEnabled = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        installRowHoverTrackingIfNeeded()
    }

    func installRowHoverTrackingIfNeeded() {
        if let rowHoverTrackingArea {
            removeTrackingArea(rowHoverTrackingArea)
            self.rowHoverTrackingArea = nil
        }
        guard rowHoverTrackingEnabled else { return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        rowHoverTrackingArea = area
    }

    func updateRowHoverTrackingEnabled(_ enabled: Bool) {
        guard rowHoverTrackingEnabled != enabled else { return }
        rowHoverTrackingEnabled = enabled
        installRowHoverTrackingIfNeeded()
        if !enabled {
            interactionController?.clearRowHoverHighlight()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        interactionController?.updateRowHover(at: point, in: self)
        super.mouseMoved(with: event)
        applyHeaderResizeCursorIfNeeded(for: event)
    }

    private func applyHeaderResizeCursorIfNeeded(for event: NSEvent) {
        guard event.type == .mouseMoved else { return }
        guard let headerView = headerView as? FileListTableHeaderView else { return }
        let pointInHeader = headerView.convert(event.locationInWindow, from: nil)
        guard headerView.bounds.contains(pointInHeader) else { return }
        _ = headerView.applyResizeCursor(at: pointInHeader)
    }

    override func mouseExited(with event: NSEvent) {
        interactionController?.clearRowHoverHighlight()
        super.mouseExited(with: event)
    }

    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?
    ) -> Any? {
        FileListDraggingDestinationSupport.validRequestor(
            servicesRequestor: servicesRequestor,
            sendType: sendType,
            returnType: returnType
        ) {
            super.validRequestor(forSendType: sendType, returnType: returnType)
        }
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
        interactionController?.skipRenameArmOnCurrentMouseUp = false
        interactionController?.commitRenameIfNeededForClick(pointInTable: point, in: self)
        
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
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        super.mouseUp(with: event)
        if row >= 0, interactionController?.skipRenameArmOnCurrentMouseUp == false {
            interactionController?.armRenameEligibleAfterClickIfNeeded(event, row: row, pointInTable: point)
        }
        interactionController?.skipRenameArmOnCurrentMouseUp = false
        interactionController?.finishPointerInteractionIfNeeded()
    }
    
    override func keyDown(with event: NSEvent) {
        if interactionController?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if interactionController?.handleKeyUp(event) == true {
            return
        }
        super.keyUp(with: event)
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        interactionController?.schedulePaddingColumnLayout()
    }
    
    // MARK: - NSDraggingDestination（比仅依赖 delegate 更可靠，跨窗口拖放尤其需要）
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileListDraggingDestinationSupport.standardDraggingUpdated {
            interactionController?.handleDraggingUpdated(sender) ?? []
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileListDraggingDestinationSupport.standardDraggingUpdated {
            interactionController?.handleDraggingUpdated(sender) ?? []
        }
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        interactionController?.clearAllDropHighlights()
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        FileListDraggingDestinationSupport.standardPrepareForDragOperation {
            interactionController?.handleDraggingUpdated(sender) ?? []
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        FileListDraggingDestinationSupport.standardPerformDragOperation {
            interactionController?.performDragOperation(sender) ?? false
        }
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        interactionController?.clearAllDropHighlights()
    }
}
