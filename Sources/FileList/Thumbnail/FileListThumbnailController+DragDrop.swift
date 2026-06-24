import AppKit
import Foundation

extension FileListThumbnailController {
    func beginDrag(for row: FileListRow, indexPath: IndexPath, event: NSEvent) {
        guard let collectionView else { return }

        resetDragDropSessionState()

        guard let dragSession = FileListDragDropSupport.beginFileDrag(
            on: collectionView,
            row: row,
            displayRows: displayRows,
            selection: effectiveSelectionIDs(),
            event: event,
            source: self
        ) else { return }

        activeDragURLs = dragSession.activeDragURLs
        activeDraggingSession = dragSession.session
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
        if let previous, previous != indexPath,
           let item = collectionView.item(at: previous) as? FileListThumbnailItem {
            item.setDropTargetHighlighted(false)
        }
        if let indexPath,
           let item = collectionView.item(at: indexPath) as? FileListThumbnailItem {
            item.setDropTargetHighlighted(true)
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

        guard let collectionView, let previous else { return }
        if let item = collectionView.item(at: previous) as? FileListThumbnailItem {
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
        FileListThumbnailCollectionLayoutSupport.smallestIndexPath(containing: point, in: collectionView)
    }

    func indexPathAtScreenPoint(_ screenPoint: NSPoint) -> IndexPath? {
        guard let collectionView, let window = collectionView.window else { return nil }
        let pointInWindow = window.convertPoint(fromScreen: screenPoint)
        let point = collectionView.convert(pointInWindow, from: nil)
        return indexPathForDrop(at: point, in: collectionView)
    }

    private func rowIndexForDrop(
        in collectionView: NSCollectionView,
        draggingInfo: NSDraggingInfo
    ) -> Int? {
        let point = dropPoint(in: collectionView, draggingInfo: draggingInfo)
        return indexPathForDrop(at: point, in: collectionView)?.item
    }

    private func applyDropHighlight(_ highlight: FileListDragDropSupport.DropHighlight) {
        switch highlight {
        case .itemRow(let row):
            setDropHighlight(indexPath: IndexPath(item: row, section: 0))
            setCurrentDirectoryDropHighlight(false)
        case .currentDirectory:
            invalidateDropTarget()
            setCurrentDirectoryDropHighlight(true)
        case .none:
            invalidateDropTarget()
            setCurrentDirectoryDropHighlight(false)
        }
    }

    func handleDraggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        guard let collectionView else {
            invalidateDropTarget()
            return []
        }

        let rowIndex = rowIndexForDrop(in: collectionView, draggingInfo: draggingInfo)

        guard let evaluation = FileListDragDropSupport.evaluateDrop(
            displayRows: displayRows,
            rowIndex: rowIndex,
            interaction: interaction,
            draggingInfo: draggingInfo,
            activeDragURLs: activeDragURLs
        ) else {
            invalidateDropTarget()
            setCurrentDirectoryDropHighlight(false)
            return []
        }

        applyDropHighlight(evaluation.highlight)
        return evaluation.operation
    }

    @discardableResult
    func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        if pendingDropTargetIndexPath == nil,
           let collectionView {
            let rowIndex = rowIndexForDrop(in: collectionView, draggingInfo: draggingInfo)
            if let evaluation = FileListDragDropSupport.evaluateDrop(
                displayRows: displayRows,
                rowIndex: rowIndex,
                interaction: interaction,
                draggingInfo: draggingInfo,
                activeDragURLs: activeDragURLs
            ), let rowIndex = evaluation.rowIndex {
                pendingDropTargetIndexPath = IndexPath(item: rowIndex, section: 0)
            }
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

        let urls = FileListDragDropSupport.resolvedURLs(
            from: pasteboard,
            fallback: activeDragURLs
        )
        guard !urls.isEmpty else { return false }

        let indexPath = explicitIndexPath ?? pendingDropTargetIndexPath ?? dropHighlightIndexPath
        if let indexPath,
           indexPath.item >= 0,
           indexPath.item < displayRows.count,
           let destinationPath = interaction.dropDestinationPath(displayRows[indexPath.item]),
           interaction.canAcceptDrop(destinationPath, urls) {
            FileListDragDropSupport.performAcceptedDrop(
                destinationPath: destinationPath,
                urls: urls,
                draggingInfo: nil,
                interaction: interaction,
                copy: operation == .copy
            )
            dropWasPerformed = true
            suppressDragSnapBack()
            return true
        }

        if let currentPath = interaction.currentDirectoryDropPath,
           interaction.canAcceptDrop(currentPath, urls) {
            FileListDragDropSupport.performAcceptedDrop(
                destinationPath: currentPath,
                urls: urls,
                draggingInfo: nil,
                interaction: interaction,
                copy: operation == .copy
            )
            dropWasPerformed = true
            suppressDragSnapBack()
            return true
        }

        return false
    }

    func suppressDragSnapBack() {
        activeDraggingSession?.animatesToStartingPositionsOnCancelOrFail = false
    }

    private func willAcceptDropAtEnd(
        operation: NSDragOperation,
        screenPoint: NSPoint,
        pasteboard: NSPasteboard
    ) -> Bool {
        let urls = FileListDragDropSupport.resolvedURLs(
            from: pasteboard,
            fallback: activeDragURLs
        )
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
}

// MARK: - NSDraggingSource

extension FileListThumbnailController: NSDraggingSource {
    public func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        FileListDragDropSupport.sourceOperationMask(for: context)
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
           let collectionView = self.collectionView {
            let rowIndex = rowIndexForDrop(in: collectionView, draggingInfo: draggingInfo)
            if let evaluation = FileListDragDropSupport.evaluateDrop(
                displayRows: displayRows,
                rowIndex: rowIndex,
                interaction: interaction,
                draggingInfo: draggingInfo,
                activeDragURLs: activeDragURLs
            ), let resolvedRow = evaluation.rowIndex {
                proposedDropIndexPath.pointee = IndexPath(item: resolvedRow, section: 0) as NSIndexPath
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
