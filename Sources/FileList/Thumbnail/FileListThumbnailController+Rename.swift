import AppKit
import Foundation

extension FileListThumbnailController: FileListRenameUIAdapter {
    var renameInteraction: FileListTableInteraction { interaction }

    func renameRow(matching id: String) -> FileListRow? {
        guard let indexPath = indexPath(for: id),
              indexPath.item >= 0,
              indexPath.item < displayRows.count else { return nil }
        return displayRows[indexPath.item]
    }

    func renameEnsureSelected(row: FileListRow) {
        guard let collectionView,
              let indexPath = indexPath(for: row.id) else { return }
        if !collectionView.selectionIndexPaths.contains(indexPath) {
            collectionView.selectionIndexPaths = [indexPath]
            syncSelectionFromCollection()
        }
    }

    func renameClearPendingTarget() {
        pendingRenameIndexPath = nil
    }

    func renameActivateEditor(for row: FileListRow) {
        guard let indexPath = indexPath(for: row.id) else { return }
        guard let item = thumbnailItem(at: indexPath) else {
            collectionView?.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.renamingRowID == row.id else { return }
                self.activateThumbnailRenameUI(at: indexPath, row: row)
            }
            return
        }
        activateThumbnailRenameUI(item: item, row: row)
    }

    func renameDeactivateEditor(forRowID rowID: String) {
        if let indexPath = indexPath(for: rowID) {
            thumbnailItem(at: indexPath)?.endRename()
        }
        refreshVisibleItemAppearance()
    }

    func renameRetryBegin(forRowID rowID: String) {
        guard let indexPath = indexPath(for: rowID) else { return }
        beginRename(indexPath: indexPath)
    }

    func beginRename(indexPath: IndexPath) {
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return }
        FileListRenamePresenter.beginRename(row: displayRows[indexPath.item], adapter: self)
    }

    public func beginRename(itemID: String) {
        guard let row = renameRow(matching: itemID) else { return }
        FileListRenamePresenter.beginRename(row: row, adapter: self)
    }

    func commitActiveRenameIfPossible() {
        guard isRenaming, let rowID = renamingRowID else { return }
        guard let indexPath = indexPath(for: rowID),
              let item = thumbnailItem(at: indexPath),
              let cell = item.view as? FileListThumbnailCellView,
              let newName = cell.activeRenameFieldValue()
        else {
            cancelRename()
            return
        }
        commitRename(newName: newName)
    }

    func cancelRename() {
        FileListRenamePresenter.cancelRename(adapter: self)
    }

    func commitRename(newName: String) {
        FileListRenamePresenter.commitRename(newName: newName, adapter: self)
    }

    private func activateThumbnailRenameUI(at indexPath: IndexPath, row: FileListRow) {
        guard let item = thumbnailItem(at: indexPath) else {
            cancelRename()
            return
        }
        activateThumbnailRenameUI(item: item, row: row)
    }

    private func activateThumbnailRenameUI(item: FileListThumbnailItem, row: FileListRow) {
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

    func shouldBeginRenameOnMouseUp(indexPath: IndexPath, pointInCollection: NSPoint) -> Bool {
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return false }
        let row = displayRows[indexPath.item]
        return renameCoordinator.shouldBeginRenameOnMouseUp(
            isSoleSelection: isSoleSelectedIndexPath(indexPath),
            isNameClickPoint: isRenameNameClickPoint(pointInCollection, indexPath: indexPath),
            canRename: interaction.canRename(row),
            isParentDirectory: row.isParentDirectoryEntry,
            itemID: row.id
        )
    }

    func armRenameEligibleAfterClickIfNeeded(_ event: NSEvent, indexPath: IndexPath, pointInCollection: NSPoint) {
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return }
        let row = displayRows[indexPath.item]
        renameCoordinator.armEligibleAfterClickIfNeeded(
            wasAlreadySelectedAtMouseDown: wasAlreadySelectedAtMouseDown,
            event: event,
            hasPendingRename: pendingRenameIndexPath != nil,
            isSoleSelection: isSoleSelectedIndexPath(indexPath),
            isNameClickPoint: isRenameNameClickPoint(pointInCollection, indexPath: indexPath),
            canRename: interaction.canRename(row),
            isParentDirectory: row.isParentDirectoryEntry,
            itemID: row.id
        )
    }

    func isRenameNameClickPoint(_ point: NSPoint, indexPath: IndexPath) -> Bool {
        guard let collectionView else { return false }
        guard let item = collectionView.item(at: indexPath) as? FileListThumbnailItem,
              let cell = item.view as? FileListThumbnailCellView
        else { return false }
        let pointInWindow = collectionView.convert(point, to: nil)
        return cell.isPointInFileNameLabel(pointInWindow)
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
        renameCoordinator.recordSelectionTimestamps(currentIDs: currentIDs)
    }

    func cancelRenameIfNeededForDataUpdate() {
        FileListRenamePresenter.cancelIfNeededForDataUpdate(adapter: self)
    }
}
