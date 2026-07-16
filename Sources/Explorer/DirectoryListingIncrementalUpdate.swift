import FileList
import Foundation

/// 目录列表增量更新：单条 stat、合并排序，避免全量 `loadItems`。
enum DirectoryListingIncrementalUpdate {
    static func loadFileItems(
        at urls: [URL],
        showHiddenFiles: Bool,
        options: DirectoryListingOptions
    ) throws -> [FileItem] {
        let keys = DirectoryListingLoader.propertyKeys(lightweight: options.lightweightMetadata)
        var items: [FileItem] = []
        items.reserveCapacity(urls.count)

        for fileURL in urls {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            let prefetchedValues = try? fileURL.resourceValues(forKeys: keys)
            let isHidden = prefetchedValues?.isHidden ?? fileURL.lastPathComponent.hasPrefix(".")
            if !showHiddenFiles, isHidden { continue }
            guard let item = TrashLoader.fileItem(
                from: fileURL,
                propertyKeys: keys,
                prefetchedValues: prefetchedValues,
                skipExtendedMetadata: options.lightweightMetadata,
                includeFinderComment: false
            ) else {
                continue
            }
            items.append(item)
        }
        return items
    }

    static func merge(
        adding added: [FileItem],
        removing removedIDs: Set<String>,
        into existing: [FileItem],
        sort: FileListSortState
    ) -> [FileItem] {
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for id in removedIDs {
            byID.removeValue(forKey: id)
        }
        for item in added {
            byID[item.id] = item
        }
        let rows = byID.values.map { FileListRow(item: $0) }
        let sortedRows = FileListSortEngine.sorted(rows, by: sort)
        return sortedRows.compactMap { byID[$0.id] }
    }
}
