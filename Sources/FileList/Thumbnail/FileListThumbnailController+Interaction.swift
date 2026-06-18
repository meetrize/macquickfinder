import AppKit
import Foundation

extension FileListThumbnailController {
    func handleCollectionFocusChanged(_ isFocused: Bool) {
        interaction.onTableFocusChanged(isFocused)
    }
    
    func willHandleItemMouseDown(_ event: NSEvent, indexPath: IndexPath) {
        wasAlreadySelectedAtMouseDown = collectionView?.selectionIndexPaths.contains(indexPath) == true
            || {
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return false }
                return effectiveSelectionIDs() == [displayRows[indexPath.item].id]
            }()
        
        mouseDownIndexPath = indexPath
        mouseDownLocation = event.locationInWindow
        mouseDownEvent = event
        mouseDownCanStartFileDrag = true
        blankMouseDownEvent = nil
        blankDragSelecting = false
        dragSessionActive = false
        pendingRenameIndexPath = nil
    }
    
    func shouldUseDefaultItemMouseDown(for indexPath: IndexPath, event: NSEvent) -> Bool {
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return true }
        if event.clickCount >= 2 { return true }
        let flags = event.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) { return true }
        // 普通单击自行处理选中，避免系统 mouseDown 进入框选追踪。
        return false
    }
    
    func handleItemClickMouseDown(indexPath: IndexPath, event: NSEvent) {
        guard let collectionView, indexPath.item >= 0, indexPath.item < displayRows.count else { return }
        guard event.clickCount == 1 else { return }
        let flags = event.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) { return }
        
        if !collectionView.selectionIndexPaths.contains(indexPath) {
            collectionView.selectionIndexPaths = [indexPath]
            syncSelectionFromCollection()
        } else if shouldBeginRenameOnMouseUp(indexPath: indexPath) {
            pendingRenameIndexPath = indexPath
        }
    }
    
    func didHandleItemMouseDown(_ event: NSEvent) {
        mouseDownEvent = event
    }
    
    func handleBlankMouseDown(_ event: NSEvent) {
        mouseDownIndexPath = nil
        mouseDownLocation = nil
        mouseDownEvent = nil
        mouseDownCanStartFileDrag = false
        dragSessionActive = false
        pendingRenameIndexPath = nil
        
        guard event.clickCount == 1 else {
            if event.clickCount >= 2 {
                interaction.onBlankDoubleClick()
            }
            return
        }
        
        blankMouseDownEvent = event
        blankDragSelecting = false
        collectionView?.window?.makeFirstResponder(collectionView)
        clearSelectionOnBlankClickIfNeeded()
        interaction.onBlankSingleClick()
    }
    
    func clearBlankDragState() {
        blankMouseDownEvent = nil
        blankDragSelecting = false
    }
    
    func handleBlankMouseUp() {
        if blankDragSelecting || dragSessionActive {
            FileListContentInteractionNotifier.notifyDidEnd()
        }
        clearBlankDragState()
        mouseDownCanStartFileDrag = false
    }
    
    func finishPointerInteractionIfNeeded() {
        if let pending = pendingRenameIndexPath {
            pendingRenameIndexPath = nil
            beginRename(indexPath: pending)
        }
        mouseDownEvent = nil
        mouseDownIndexPath = nil
        mouseDownLocation = nil
        mouseDownCanStartFileDrag = false
    }
    
    private func clearSelectionOnBlankClickIfNeeded() {
        guard let collectionView else { return }
        let hasSelection = !collectionView.selectionIndexPaths.isEmpty
            || !(selectionGet?().isEmpty ?? true)
        guard hasSelection else { return }
        
        collectionView.selectionIndexPaths = []
        selectionSet?([])
        refreshVisibleItemAppearance()
    }
    
    func handleMouseDragged(_ event: NSEvent) -> Bool {
        if isRenaming { return false }
        
        if let start = mouseDownLocation {
            let distance = hypot(
                event.locationInWindow.x - start.x,
                event.locationInWindow.y - start.y
            )
            if distance >= dragThreshold, pendingRenameIndexPath != nil {
                pendingRenameIndexPath = nil
            }
        }
        
        if handleBlankRubberBandDrag(event) { return true }
        
        let itemDragPending = !dragSessionActive
            && mouseDownIndexPath != nil
            && mouseDownCanStartFileDrag
            && mouseDownEvent != nil
            && mouseDownLocation != nil
        
        guard itemDragPending,
              let start = mouseDownLocation,
              let indexPath = mouseDownIndexPath else { return dragSessionActive }
        
        let distance = hypot(
            event.locationInWindow.x - start.x,
            event.locationInWindow.y - start.y
        )
        guard distance >= dragThreshold else { return true }
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return true }
        
        if let collectionView, !collectionView.selectionIndexPaths.contains(indexPath) {
            let flags = mouseDownEvent?.modifierFlags ?? []
            if !flags.contains(.command), !flags.contains(.shift) {
                collectionView.selectionIndexPaths = [indexPath]
                syncSelectionFromCollection()
            }
        }
        
        dragSessionActive = true
        beginDrag(for: displayRows[indexPath.item], indexPath: indexPath, event: event)
        return true
    }
    
    private func handleBlankRubberBandDrag(_ event: NSEvent) -> Bool {
        guard let startEvent = blankMouseDownEvent, let collectionView else { return false }
        
        if !blankDragSelecting {
            let deltaX = event.locationInWindow.x - startEvent.locationInWindow.x
            let deltaY = event.locationInWindow.y - startEvent.locationInWindow.y
            guard hypot(deltaX, deltaY) >= dragThreshold else { return true }
            blankDragSelecting = true
            FileListContentInteractionNotifier.notifyDidBegin()
        }
        
        let startPoint = collectionView.convert(startEvent.locationInWindow, from: nil)
        let currentPoint = collectionView.convert(event.locationInWindow, from: nil)
        let selectionRect = NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
        
        var indexPaths = Set<IndexPath>()
        for item in 0..<displayRows.count {
            let indexPath = IndexPath(item: item, section: 0)
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else { continue }
            if frame.intersects(selectionRect) {
                indexPaths.insert(indexPath)
            }
        }
        collectionView.selectionIndexPaths = indexPaths
        syncSelectionFromCollection()
        return true
    }
    
    func handleRightMouseDown(_ event: NSEvent) {
        guard let collectionView else { return }
        let point = collectionView.convert(event.locationInWindow, from: nil)
        
        if let indexPath = collectionView.indexPath(at: point),
           indexPath.item >= 0,
           indexPath.item < displayRows.count {
            if !collectionView.selectionIndexPaths.contains(indexPath) {
                collectionView.selectionIndexPaths = [indexPath]
                syncSelectionFromCollection()
            }
            let clickedRow = displayRows[indexPath.item]
            let selectedIDs = selectedIDs(from: collectionView)
            if let menu = interaction.makeContextMenu(clickedRow, selectedIDs) {
                NSMenu.popUpContextMenu(menu, with: event, for: collectionView)
            }
            return
        }
        
        guard collectionView.bounds.contains(point), interaction.blankMenuActions.isEnabled else { return }
        showBlankContextMenu(for: event)
    }
    
    private func selectedIDs(from collectionView: NSCollectionView) -> Set<String> {
        Set(
            collectionView.selectionIndexPaths.compactMap { indexPath -> String? in
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return nil }
                return displayRows[indexPath.item].id
            }
        )
    }
    
    private func showBlankContextMenu(for event: NSEvent) {
        guard let collectionView else { return }
        let controller = FileListBlankMenuController(actions: interaction.blankMenuActions)
        controller.popUp(with: event, for: collectionView)
    }
    
    func handleKeyDown(_ event: NSEvent) -> Bool {
        if isRenaming { return true }
        
        if handleArrowKeyNavigation(event) { return true }
        
        if event.keyCode == 120 {
            guard let indexPath = collectionView?.selectionIndexPaths.sorted(by: { $0.item < $1.item }).first else {
                return false
            }
            beginRename(indexPath: indexPath)
            return true
        }
        
        if event.keyCode == 49 {
            guard !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.option) else { return false }
            guard !effectiveSelectionIDs().isEmpty else { return false }
            interaction.onSpacePreview()
            return true
        }
        
        if event.keyCode == 36 || event.keyCode == 76 {
            guard !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.option),
                  let collectionView
            else { return false }
            guard let indexPath = collectionView.selectionIndexPaths.sorted(by: { $0.item < $1.item }).first,
                  indexPath.item >= 0,
                  indexPath.item < displayRows.count else { return false }
            onOpenRow?(displayRows[indexPath.item])
            return true
        }
        
        let flags = event.modifierFlags
        if !flags.contains(.command), !flags.contains(.control), !flags.contains(.option) {
            if event.keyCode == 53 {
                interaction.onQuickSearchEscape()
                return true
            }
            if event.keyCode == 51 || event.keyCode == 117 {
                if !interaction.quickSearchText.isEmpty {
                    interaction.onQuickSearchBackspace()
                    return true
                }
                if event.keyCode == 51,
                   effectiveSelectionIDs().isEmpty,
                   interaction.canNavigateBack() {
                    interaction.onNavigateBack()
                    return true
                }
            }
            if let input = quickSearchInputCharacter(from: event) {
                interaction.onQuickSearchInput(input)
                return true
            }
        }
        
        guard event.keyCode == 51 || event.keyCode == 117 else { return false }
        guard !flags.contains(.command) else { return false }
        guard interaction.canDelete() else { return false }
        interaction.onDelete()
        return true
    }
    
    private func handleArrowKeyNavigation(_ event: NSEvent) -> Bool {
        guard let collectionView else { return false }
        let columns = gridColumnCount()
        let current = collectionView.selectionIndexPaths.sorted(by: { $0.item < $1.item }).first
            ?? IndexPath(item: 0, section: 0)
        var nextItem = current.item
        
        switch event.keyCode {
        case 126: nextItem -= columns
        case 125: nextItem += columns
        case 123: nextItem -= 1
        case 124: nextItem += 1
        default: return false
        }
        
        guard nextItem >= 0, nextItem < displayRows.count else { return true }
        let nextPath = IndexPath(item: nextItem, section: 0)
        collectionView.selectionIndexPaths = [nextPath]
        syncSelectionFromCollection()
        collectionView.scrollToItems(at: [nextPath], scrollPosition: .nearestVerticalEdge)
        return true
    }
    
    private func quickSearchInputCharacter(from event: NSEvent) -> String? {
        guard let input = event.charactersIgnoringModifiers, input.count == 1,
              let scalar = input.unicodeScalars.first
        else { return nil }
        
        if CharacterSet.whitespacesAndNewlines.contains(scalar) { return nil }
        if CharacterSet.controlCharacters.contains(scalar) { return nil }
        if (0xF700...0xF8FF).contains(scalar.value) { return nil }
        
        if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
            return input
        }
        return nil
    }
}
