import AppKit
import Foundation

extension FileListThumbnailController {
    func beginDrag(for row: FileListRow, indexPath: IndexPath, event: NSEvent) {
        guard let collectionView else { return }
        let dragged = FileListDragSupport.draggedRows(
            for: row,
            in: displayRows,
            selection: effectiveSelectionIDs()
        )
        guard !dragged.isEmpty else { return }

        FileListContentInteractionNotifier.notifyDidBegin()
        
        resetDragDropSessionState()
        activeDragURLs = dragged.map { URL(fileURLWithPath: $0.iconPath) }
        
        let mousePoint = collectionView.convert(event.locationInWindow, from: nil)
        var draggingItems: [NSDraggingItem] = []
        for (index, draggedRow) in dragged.enumerated() {
            let showLabel = dragged.count == 1 || draggedRow.id == row.id
            let ghost = FileListDragSupport.makeDragGhost(
                for: draggedRow.iconPath,
                name: draggedRow.name,
                showLabel: showLabel
            )
            let frame = FileListDragSupport.draggingFrame(
                at: mousePoint,
                ghostSize: ghost.size,
                index: index
            )
            let url = URL(fileURLWithPath: draggedRow.iconPath) as NSURL
            let draggingItem = NSDraggingItem(pasteboardWriter: url)
            draggingItem.setDraggingFrame(frame, contents: ghost.image)
            draggingItems.append(draggingItem)
        }
        
        let session = collectionView.beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = dragged.count > 1 ? .pile : .none
        activeDraggingSession = session
        _ = indexPath
    }
    
    func setDropHighlight(indexPath: IndexPath?) {
        if let indexPath {
            pendingDropTargetIndexPath = indexPath
        }
        
        let previous = dropHighlightIndexPath
        guard previous != indexPath else { return }
        dropHighlightIndexPath = indexPath
        
        if indexPath != nil {
            suppressDragSnapBack()
        } else if activeDraggingSession != nil {
            activeDraggingSession?.animatesToStartingPositionsOnCancelOrFail = true
        }
        
        guard let collectionView else { return }
        for visiblePath in collectionView.indexPathsForVisibleItems() {
            guard let item = collectionView.item(at: visiblePath) as? FileListThumbnailItem else { continue }
            item.setDropTargetHighlighted(visiblePath == indexPath)
        }
    }
    
    func invalidateDropTarget() {
        pendingDropTargetIndexPath = nil
        setDropHighlight(indexPath: nil)
    }
    
    func setCurrentDirectoryDropHighlight(_ isTargeted: Bool) {
        interaction.onCurrentDirectoryDropHighlightChanged(isTargeted)
    }
    
    func clearDropHighlightVisualOnly() {
        let previous = dropHighlightIndexPath
        guard previous != nil else { return }
        dropHighlightIndexPath = nil
        
        guard let collectionView else { return }
        for visiblePath in collectionView.indexPathsForVisibleItems() {
            guard let item = collectionView.item(at: visiblePath) as? FileListThumbnailItem else { continue }
            item.setDropTargetHighlighted(false)
        }
    }
    
    func resetDragDropSessionState() {
        pendingDropTargetIndexPath = nil
        activeDragURLs = nil
        dropWasPerformed = false
        activeDraggingSession = nil
        clearDropHighlightVisualOnly()
    }
    
    /// 与 NSTableView 一致：draggingLocation 为窗口坐标。
    func dropPoint(in collectionView: NSCollectionView, draggingInfo: NSDraggingInfo) -> NSPoint {
        collectionView.convert(draggingInfo.draggingLocation, from: nil)
    }
    
    func indexPathForDrop(at point: NSPoint, in collectionView: NSCollectionView) -> IndexPath? {
        var bestMatch: (indexPath: IndexPath, area: CGFloat)?
        
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else { continue }
            guard frame.contains(point) else { continue }
            let area = frame.width * frame.height
            if bestMatch == nil || area < bestMatch!.area {
                bestMatch = (indexPath, area)
            }
        }
        
        if let bestMatch {
            return bestMatch.indexPath
        }
        return collectionView.indexPathForItem(at: point)
    }
    
    func indexPathAtScreenPoint(_ screenPoint: NSPoint) -> IndexPath? {
        guard let collectionView, let window = collectionView.window else { return nil }
        let pointInWindow = window.convertPoint(fromScreen: screenPoint)
        let point = collectionView.convert(pointInWindow, from: nil)
        return indexPathForDrop(at: point, in: collectionView)
    }
    
    func resolvedDropTarget(
        in collectionView: NSCollectionView,
        draggingInfo: NSDraggingInfo
    ) -> (indexPath: IndexPath?, destinationPath: String)? {
        let urls = resolvedDragURLs(from: draggingInfo.draggingPasteboard)
        guard !urls.isEmpty else { return nil }
        
        let point = dropPoint(in: collectionView, draggingInfo: draggingInfo)
        if let indexPath = indexPathForDrop(at: point, in: collectionView),
           indexPath.item >= 0,
           indexPath.item < displayRows.count {
            let row = displayRows[indexPath.item]
            if let destinationPath = interaction.dropDestinationPath(row),
               interaction.canAcceptDrop(destinationPath, urls) {
                return (indexPath, destinationPath)
            }
        }
        
        if let currentPath = interaction.currentDirectoryDropPath,
           interaction.canAcceptDrop(currentPath, urls) {
            return (nil, currentPath)
        }
        
        return nil
    }
    
    func handleDraggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        guard let collectionView else {
            invalidateDropTarget()
            return []
        }
        
        let urls = resolvedDragURLs(from: draggingInfo.draggingPasteboard)
        guard !urls.isEmpty else {
            invalidateDropTarget()
            return []
        }
        
        guard let target = resolvedDropTarget(in: collectionView, draggingInfo: draggingInfo),
              interaction.canAcceptDrop(target.destinationPath, urls) else {
            invalidateDropTarget()
            setCurrentDirectoryDropHighlight(false)
            return []
        }
        
        if let indexPath = target.indexPath {
            setDropHighlight(indexPath: indexPath)
            setCurrentDirectoryDropHighlight(false)
        } else {
            invalidateDropTarget()
            setCurrentDirectoryDropHighlight(true)
        }
        return FileListDragSupport.shouldCopy(from: draggingInfo) ? .copy : .move
    }
    
    @discardableResult
    func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        if pendingDropTargetIndexPath == nil,
           let collectionView,
           let target = resolvedDropTarget(in: collectionView, draggingInfo: draggingInfo) {
            pendingDropTargetIndexPath = target.indexPath
        }
        suppressDragSnapBack()
        let copy = FileListDragSupport.shouldCopy(from: draggingInfo)
        let performed = completeDropIfPossible(
            pasteboard: draggingInfo.draggingPasteboard,
            operation: copy ? .copy : .move
        )
        if performed {
            setCurrentDirectoryDropHighlight(false)
        }
        return performed
    }
    
    @discardableResult
    func completeDropAtEndOfDragSession(
        pasteboard: NSPasteboard,
        operation: NSDragOperation,
        screenPoint: NSPoint
    ) -> Bool {
        guard !dropWasPerformed else { return true }
        
        if operation != [] {
            let resolvedOperation: NSDragOperation = operation.contains(.copy) ? .copy : .move
            if completeDropIfPossible(pasteboard: pasteboard, operation: resolvedOperation) {
                return true
            }
        }
        
        guard let pending = pendingDropTargetIndexPath,
              let resolved = indexPathAtScreenPoint(screenPoint),
              resolved == pending else {
            return false
        }
        
        return completeDropIfPossible(pasteboard: pasteboard, operation: .move, indexPath: pending)
    }
    
    @discardableResult
    private func completeDropIfPossible(
        pasteboard: NSPasteboard,
        operation: NSDragOperation,
        indexPath explicitIndexPath: IndexPath? = nil
    ) -> Bool {
        guard operation != [], !dropWasPerformed else { return dropWasPerformed }
        
        let urls = resolvedDragURLs(from: pasteboard)
        guard !urls.isEmpty else { return false }
        
        let indexPath = explicitIndexPath ?? pendingDropTargetIndexPath ?? dropHighlightIndexPath
        let row: FileListRow?
        if let indexPath,
           indexPath.item >= 0,
           indexPath.item < displayRows.count {
            row = displayRows[indexPath.item]
        } else if let currentPath = interaction.currentDirectoryDropPath,
                  interaction.canAcceptDrop(currentPath, urls) {
            interaction.performDrop(currentPath, urls, operation == .copy)
            dropWasPerformed = true
            suppressDragSnapBack()
            return true
        } else {
            row = nil
        }
        
        guard let row,
              let destinationPath = interaction.dropDestinationPath(row),
              interaction.canAcceptDrop(destinationPath, urls) else {
            return false
        }
        
        interaction.performDrop(destinationPath, urls, operation == .copy)
        dropWasPerformed = true
        suppressDragSnapBack()
        return true
    }
    
    func suppressDragSnapBack() {
        activeDraggingSession?.animatesToStartingPositionsOnCancelOrFail = false
    }
    
    private func willAcceptDropAtEnd(
        operation: NSDragOperation,
        screenPoint: NSPoint,
        pasteboard: NSPasteboard
    ) -> Bool {
        let urls = resolvedDragURLs(from: pasteboard)
        guard !urls.isEmpty else { return false }
        
        let indexPath: IndexPath?
        if let pending = pendingDropTargetIndexPath,
           let resolved = indexPathAtScreenPoint(screenPoint),
           resolved == pending {
            indexPath = pending
        } else if operation != [] {
            indexPath = pendingDropTargetIndexPath ?? dropHighlightIndexPath
        } else {
            return false
        }
        
        guard let indexPath,
              indexPath.item >= 0,
              indexPath.item < displayRows.count,
              let destinationPath = interaction.dropDestinationPath(displayRows[indexPath.item]),
              interaction.canAcceptDrop(destinationPath, urls) else {
            return false
        }
        return true
    }
    
    private func resolvedDragURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls = FileListDragSupport.fileURLs(from: pasteboard)
        if urls.isEmpty, let activeDragURLs {
            urls = activeDragURLs
        }
        return urls
    }
}

// MARK: - NSDraggingSource

extension FileListThumbnailController: NSDraggingSource {
    public func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        if FileListDragSupport.shouldCopyFromCurrentEvent() {
            return .copy
        }
        switch context {
        case .withinApplication:
            return .move
        default:
            return .move
        }
    }
    
    public func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if willAcceptDropAtEnd(
            operation: operation,
            screenPoint: screenPoint,
            pasteboard: session.draggingPasteboard
        ) {
            session.animatesToStartingPositionsOnCancelOrFail = false
        }
        
        _ = completeDropAtEndOfDragSession(
            pasteboard: session.draggingPasteboard,
            operation: operation,
            screenPoint: screenPoint
        )
        
        let didDrop = dropWasPerformed
        resetDragDropSessionState()
        dragSessionActive = false
        FileListContentInteractionNotifier.notifyDidEnd()
        mouseDownLocation = nil
        mouseDownEvent = nil
        mouseDownCanStartFileDrag = false
        finishPointerInteractionIfNeeded()
        if didDrop || operation != [] {
            DispatchQueue.main.async { [weak self] in
                self?.interaction.onDragEnded()
            }
        }
    }
}

// MARK: - NSCollectionViewDelegate

extension FileListThumbnailController {
    public func collectionView(
        _ collectionView: NSCollectionView,
        validateDrop draggingInfo: NSDraggingInfo,
        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        let operation = handleDraggingUpdated(draggingInfo)
        if operation != [],
           let target = resolvedDropTarget(in: collectionView, draggingInfo: draggingInfo) {
            if let indexPath = target.indexPath {
                proposedDropIndexPath.pointee = indexPath as NSIndexPath
            } else {
                proposedDropIndexPath.pointee = NSIndexPath(forItem: NSNotFound, inSection: 0)
            }
            proposedDropOperation.pointee = .on
        }
        return operation
    }
    
    public func collectionView(
        _ collectionView: NSCollectionView,
        acceptDrop draggingInfo: NSDraggingInfo,
        indexPath: IndexPath,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        pendingDropTargetIndexPath = indexPath
        return performDragOperation(draggingInfo)
    }
}
