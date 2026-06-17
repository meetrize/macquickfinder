import AppKit
import Foundation

extension FileListThumbnailController {
    var isRenaming: Bool { renamingRowID != nil }
    
    func beginRename(indexPath: IndexPath) {
        guard renamingRowID == nil else { return }
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return }
        let row = displayRows[indexPath.item]
        guard !row.isParentDirectoryEntry else { return }
        guard interaction.canRename(row) else { return }
        
        if let collectionView, !collectionView.selectionIndexPaths.contains(indexPath) {
            collectionView.selectionIndexPaths = [indexPath]
            syncSelectionFromCollection()
        }
        
        renamingRowID = row.id
        pendingRenameIndexPath = nil
        interaction.onRenameEditingChanged(true)
        
        guard let item = thumbnailItem(at: indexPath) else {
            collectionView?.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.renamingRowID == row.id else { return }
                self.beginRenameUI(at: indexPath, row: row)
            }
            return
        }
        beginRenameUI(item: item, row: row)
    }
    
    private func beginRenameUI(at indexPath: IndexPath, row: FileListRow) {
        guard let item = thumbnailItem(at: indexPath) else {
            cancelRename()
            return
        }
        beginRenameUI(item: item, row: row)
    }
    
    private func beginRenameUI(item: FileListThumbnailItem, row: FileListRow) {
        item.beginRename(
            name: row.name,
            onCommit: { [weak self] newName in
                self?.commitRename(newName: newName)
            },
            onCancel: { [weak self] in
                self?.cancelRename()
            }
        )
    }
    
    func cancelRename() {
        guard let rowID = renamingRowID,
              let indexPath = indexPath(for: rowID) else {
            renamingRowID = nil
            pendingRenameIndexPath = nil
            interaction.onRenameEditingChanged(false)
            return
        }
        
        thumbnailItem(at: indexPath)?.endRename()
        renamingRowID = nil
        pendingRenameIndexPath = nil
        interaction.onRenameEditingChanged(false)
        refreshVisibleItemAppearance()
    }
    
    func commitRename(newName: String) {
        guard let rowID = renamingRowID,
              let indexPath = indexPath(for: rowID),
              indexPath.item >= 0,
              indexPath.item < displayRows.count else { return }
        let row = displayRows[indexPath.item]
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty || trimmed == row.name {
            cancelRename()
            return
        }
        
        renamingRowID = nil
        pendingRenameIndexPath = nil
        interaction.onRenameEditingChanged(false)
        thumbnailItem(at: indexPath)?.endRename()
        refreshVisibleItemAppearance()
        
        interaction.performRename(row, trimmed) { [weak self] success in
            guard let self, !success else { return }
            if let retryPath = self.indexPath(for: rowID) {
                self.beginRename(indexPath: retryPath)
            }
        }
    }
    
    func shouldBeginRenameOnMouseUp(indexPath: IndexPath) -> Bool {
        guard !isRenaming else { return false }
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return false }
        guard mouseDownCanStartFileDrag else { return false }
        guard isSoleSelectedIndexPath(indexPath) else { return false }
        
        let row = displayRows[indexPath.item]
        guard !row.isParentDirectoryEntry else { return false }
        guard interaction.canRename(row) else { return false }
        return isWithinRenameSecondClickWindow(itemID: row.id)
    }
    
    func armRenameEligibleAfterClickIfNeeded(_ event: NSEvent, indexPath: IndexPath) {
        guard renamingRowID == nil, pendingRenameIndexPath == nil else { return }
        guard wasAlreadySelectedAtMouseDown else { return }
        guard event.clickCount == 1 else { return }
        let flags = event.modifierFlags
        guard !flags.contains(.command), !flags.contains(.shift) else { return }
        guard isSoleSelectedIndexPath(indexPath) else { return }
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return }
        
        let row = displayRows[indexPath.item]
        guard !row.isParentDirectoryEntry, interaction.canRename(row) else { return }
        rowRenameEligibleSince[row.id] = Date()
    }
    
    func isSoleSelectedIndexPath(_ indexPath: IndexPath) -> Bool {
        guard let collectionView else { return false }
        if collectionView.selectionIndexPaths == [indexPath] { return true }
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return false }
        let rowID = displayRows[indexPath.item].id
        return effectiveSelectionIDs() == [rowID]
    }
    
    func recordRenameSelectionTimestamps() {
        guard let collectionView else { return }
        let currentIDs = Set(
            collectionView.selectionIndexPaths.compactMap { indexPath -> String? in
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return nil }
                return displayRows[indexPath.item].id
            }
        )
        let now = Date()
        for id in currentIDs.subtracting(lastKnownSelectionIDs) {
            rowRenameEligibleSince[id] = now
        }
        for id in lastKnownSelectionIDs.subtracting(currentIDs) {
            rowRenameEligibleSince.removeValue(forKey: id)
        }
        lastKnownSelectionIDs = currentIDs
    }
    
    private func isWithinRenameSecondClickWindow(itemID: String) -> Bool {
        guard let selectedAt = rowRenameEligibleSince[itemID] else { return false }
        let elapsed = Date().timeIntervalSince(selectedAt)
        return elapsed > NSEvent.doubleClickInterval
            && elapsed <= Self.renameSecondClickMaxInterval
    }
    
    func cancelRenameIfNeededForDataUpdate() {
        guard renamingRowID != nil else { return }
        renamingRowID = nil
        pendingRenameIndexPath = nil
        interaction.onRenameEditingChanged(false)
    }
}
