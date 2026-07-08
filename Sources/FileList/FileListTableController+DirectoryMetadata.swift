import AppKit
import Foundation

// MARK: - Directory size metadata

extension FileListTableController {
    public func refreshDirectorySizeColumnIfNeeded(_ provider: DirectorySizeColumnProvider?) {
        directorySizeDisplay = provider?.display
        guard let provider else { return }
        guard provider.revision != lastDirectorySizeRevision else {
            flushPendingDirectorySizeRefreshIfNeeded()
            return
        }
        lastDirectorySizeRevision = provider.revision
        applyDirectorySizeDisplayUpdates()
    }

    func flushPendingDirectorySizeRefreshIfNeeded() {
        guard pendingDirectorySizeRefresh else { return }
        applyDirectorySizeDisplayUpdates()
    }

    func applyDirectorySizeDisplayUpdates() {
        guard let directorySizeDisplay else { return }
        if isUserPointerActive {
            pendingDirectorySizeRefresh = true
            return
        }
        pendingDirectorySizeRefresh = false

        var updatedSource = sourceRows
        var changed = false
        for index in updatedSource.indices {
            let row = updatedSource[index]
            guard row.isDirectory, !row.isParentDirectoryEntry else { continue }
            let updated = row.withDirectorySizeDisplay(directorySizeDisplay(row.iconPath))
            if updated != row {
                updatedSource[index] = updated
                changed = true
            }
        }
        guard changed else { return }

        sourceRows = updatedSource
        let sort = preferencesStore?.sort ?? FileListSortState.default
        let previousOrder = displayRows.map(\.id)
        displayRows = FileListSortEngine.sorted(sourceRows, by: sort)
        let orderChanged = displayRows.map(\.id) != previousOrder

        if orderChanged {
            FileListTableAnimations.performWithoutAnimation {
                tableView?.reloadData()
            }
            syncSelectionToTable()
        } else {
            reloadSizeColumnPreservingScroll()
        }
    }

    func sizeColumnIndex(in tableView: NSTableView) -> Int? {
        tableView.tableColumns.firstIndex { FileListColumnID.from(column: $0) == .size }
    }
}
