import Foundation

/// 目录大小与子项数量的合并回填与批量更新。
enum FileListDirectoryMetadataRefresh {
    struct Providers {
        var directorySize: ((String) -> DirectorySizeDisplayInfo)?
        var directoryItemCount: ((String) -> DirectoryItemCountDisplayInfo)?
    }

    static func mergePreservingMetadata(
        incoming: [FileListRow],
        existing: [FileListRow],
        providers: Providers
    ) -> [FileListRow] {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        return incoming.map { row in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            var updated = row

            if let directorySize = providers.directorySize {
                let info = directorySize(row.iconPath)
                if info != .unknown {
                    updated = updated.withDirectorySizeDisplay(info)
                }
            } else if let cached = existingByID[row.id], cached.sizeDisplay != "--" {
                updated = updated.withDirectorySizeDisplay(
                    DirectorySizeDisplayInfo(sortableSize: cached.size, text: cached.sizeDisplay)
                )
            }

            if let directoryItemCount = providers.directoryItemCount,
               !FileListApplicationBundle.isBundle(path: row.iconPath) {
                let info = directoryItemCount(row.iconPath)
                if info != .unknown {
                    updated = updated.withChildCountDisplay(info)
                }
            } else if let cached = existingByID[row.id], let childCount = cached.childCountDisplay,
                      !FileListApplicationBundle.isBundle(path: row.iconPath) {
                updated = updated.withChildCountDisplay(
                    DirectoryItemCountDisplayInfo(count: -1, text: childCount)
                )
            }

            return updated
        }
    }

    static func mergePreservingDirectorySizes(
        incoming: [FileListRow],
        existing: [FileListRow],
        directorySizeDisplay: ((String) -> DirectorySizeDisplayInfo)?
    ) -> [FileListRow] {
        mergePreservingMetadata(
            incoming: incoming,
            existing: existing,
            providers: Providers(directorySize: directorySizeDisplay, directoryItemCount: nil)
        )
    }

    struct ApplyResult {
        var sourceRows: [FileListRow]
        var displayRows: [FileListRow]
        var changed: Bool
    }

    static func applySizeDisplayUpdates(
        sourceRows: [FileListRow],
        displayRows: [FileListRow],
        display: (String) -> DirectorySizeDisplayInfo
    ) -> ApplyResult {
        var changed = false
        let updatedSource = sourceRows.map { row -> FileListRow in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            let updated = row.withDirectorySizeDisplay(display(row.iconPath))
            if updated != row {
                changed = true
                return updated
            }
            return row
        }
        let updatedDisplay = displayRows.map { row -> FileListRow in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            let info = display(row.iconPath)
            guard info != .unknown, row.sizeDisplay != info.text else { return row }
            changed = true
            return row.withDirectorySizeDisplay(info)
        }
        return ApplyResult(
            sourceRows: updatedSource,
            displayRows: updatedDisplay,
            changed: changed
        )
    }

    static func applyItemCountDisplayUpdates(
        sourceRows: [FileListRow],
        displayRows: [FileListRow],
        display: (String) -> DirectoryItemCountDisplayInfo
    ) -> ApplyResult {
        var changed = false
        let updatedSource = sourceRows.map { row -> FileListRow in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            guard !FileListApplicationBundle.isBundle(path: row.iconPath) else { return row }
            let info = display(row.iconPath)
            guard info != .unknown, row.childCountDisplay != info.text else { return row }
            changed = true
            return row.withChildCountDisplay(info)
        }
        let updatedDisplay = displayRows.map { row -> FileListRow in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            guard !FileListApplicationBundle.isBundle(path: row.iconPath) else { return row }
            let info = display(row.iconPath)
            guard info != .unknown, row.childCountDisplay != info.text else { return row }
            changed = true
            return row.withChildCountDisplay(info)
        }
        return ApplyResult(
            sourceRows: updatedSource,
            displayRows: updatedDisplay,
            changed: changed
        )
    }
}
