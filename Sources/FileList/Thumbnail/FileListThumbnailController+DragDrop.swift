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
        _ = indexPath
    }
    
    func setDropHighlight(indexPath: IndexPath?) {
        guard dropHighlightIndexPath != indexPath else { return }
        if let previous = dropHighlightIndexPath {
            thumbnailItem(at: previous)?.setDropTargetHighlighted(false)
        }
        dropHighlightIndexPath = indexPath
        if let indexPath {
            thumbnailItem(at: indexPath)?.setDropTargetHighlighted(true)
        }
    }
    
    func clearDropHighlight() {
        setDropHighlight(indexPath: nil)
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
        dragSessionActive = false
        cancelSpringLoading()
        mouseDownLocation = nil
        mouseDownEvent = nil
        mouseDownCanStartFileDrag = false
        finishPointerInteractionIfNeeded()
        if operation != [] {
            DispatchQueue.main.async { [weak self] in
                self?.interaction.onDragEnded()
            }
        }
    }
    
    public func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard let collectionView, let window = collectionView.window else {
            cancelSpringLoading()
            return
        }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let point = collectionView.convert(windowPoint, from: nil)
        handleSpringLoadingHover(at: springLoadingIndexPath(at: point))
    }
}

// MARK: - Drop destination

extension FileListThumbnailController {
    public func collectionView(
        _ collectionView: NSCollectionView,
        validateDrop draggingInfo: NSDraggingInfo,
        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        let urls = FileListDragSupport.fileURLs(from: draggingInfo.draggingPasteboard)
        guard !urls.isEmpty else {
            clearDropHighlight()
            cancelSpringLoading()
            return []
        }
        
        let point = collectionView.convert(draggingInfo.draggingLocation, from: nil)
        guard let indexPath = collectionView.indexPathForItem(at: point),
              indexPath.item >= 0,
              indexPath.item < displayRows.count else {
            clearDropHighlight()
            cancelSpringLoading()
            return []
        }
        
        let row = displayRows[indexPath.item]
        guard let destinationPath = interaction.dropDestinationPath(row),
              interaction.canAcceptDrop(destinationPath, urls) else {
            clearDropHighlight()
            cancelSpringLoading()
            return []
        }
        
        proposedDropIndexPath.pointee = indexPath as NSIndexPath
        proposedDropOperation.pointee = .on
        setDropHighlight(indexPath: indexPath)
        handleSpringLoadingHover(at: indexPath)
        return FileListDragSupport.shouldCopyFromCurrentEvent() ? .copy : .move
    }
    
    public func collectionView(
        _ collectionView: NSCollectionView,
        acceptDrop draggingInfo: NSDraggingInfo,
        indexPath: IndexPath,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        clearDropHighlight()
        cancelSpringLoading()
        let urls = FileListDragSupport.fileURLs(from: draggingInfo.draggingPasteboard)
        guard !urls.isEmpty,
              indexPath.item >= 0,
              indexPath.item < displayRows.count else { return false }
        guard let destinationPath = interaction.dropDestinationPath(displayRows[indexPath.item]) else {
            return false
        }
        
        let copy = FileListDragSupport.shouldCopyFromCurrentEvent()
        interaction.performDrop(destinationPath, urls, copy)
        return true
    }
}
