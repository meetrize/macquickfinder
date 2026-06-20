import Combine
import FileList
import Foundation

@MainActor
final class PreviewBrowserContext: ObservableObject {
    let directoryPath: String
    let sortSnapshot: FileListSortState
    let showHiddenFiles: Bool

    /// detach 时捕获的全部可预览项（未做同类型过滤）。
    let sourceItems: [FileItem]

    @Published var sameTypeOnly: Bool
    @Published private(set) var orderedItems: [FileItem]
    @Published var currentIndex: Int

    var currentItem: FileItem {
        orderedItems[currentIndex]
    }

    var count: Int {
        orderedItems.count
    }

    var canBrowse: Bool {
        orderedItems.count > 1
    }

    var positionLabel: String {
        "\(currentIndex + 1)/\(count)"
    }

    init(
        directoryPath: String,
        sortSnapshot: FileListSortState,
        showHiddenFiles: Bool,
        sourceItems: [FileItem],
        sameTypeOnly: Bool,
        orderedItems: [FileItem],
        currentIndex: Int
    ) {
        self.directoryPath = directoryPath
        self.sortSnapshot = sortSnapshot
        self.showHiddenFiles = showHiddenFiles
        self.sourceItems = sourceItems
        self.sameTypeOnly = sameTypeOnly
        self.orderedItems = orderedItems
        self.currentIndex = min(max(currentIndex, 0), max(orderedItems.count - 1, 0))
    }

    func item(at offset: Int) -> FileItem? {
        let index = currentIndex + offset
        guard orderedItems.indices.contains(index) else { return nil }
        return orderedItems[index]
    }

    @discardableResult
    func select(index: Int) -> Bool {
        guard orderedItems.indices.contains(index) else { return false }
        currentIndex = index
        return true
    }

    @discardableResult
    func selectPrevious() -> Bool {
        guard currentIndex > 0 else { return false }
        currentIndex -= 1
        return true
    }

    @discardableResult
    func selectNext() -> Bool {
        guard currentIndex + 1 < orderedItems.count else { return false }
        currentIndex += 1
        return true
    }

    func setSameTypeOnly(_ enabled: Bool) {
        guard sameTypeOnly != enabled else { return }
        sameTypeOnly = enabled
        rebuildOrderedItems(keepingFileID: currentItem.id)
    }

    /// 从当前目录列表构建浏览快照；仅含可预览的非目录项。
    static func makeSnapshot(
        directoryPath: String,
        items: [FileItem],
        sortOrder: SortOrder,
        showHiddenFiles: Bool,
        currentFileID: String,
        sameTypeOnly: Bool? = nil
    ) -> PreviewBrowserContext? {
        makeSnapshot(
            directoryPath: directoryPath,
            items: items,
            sortSnapshot: FileListSortState(sortOrder: sortOrder),
            showHiddenFiles: showHiddenFiles,
            currentFileID: currentFileID,
            sameTypeOnly: sameTypeOnly
        )
    }

    static func makeSnapshot(
        directoryPath: String,
        items: [FileItem],
        sortSnapshot: FileListSortState,
        showHiddenFiles: Bool,
        currentFileID: String,
        sameTypeOnly: Bool? = nil
    ) -> PreviewBrowserContext? {
        let resolvedSameTypeOnly = sameTypeOnly
            ?? UserDefaults.standard.bool(forKey: ExplorerAppSettings.previewBrowserSameTypeOnlyKey)

        let candidates = items.filter { item in
            guard !item.isParentDirectoryEntry, !item.isDirectory else { return false }
            if !showHiddenFiles, item.isHidden { return false }
            return PreviewBrowserEligibility.canPreviewInDetachedWindow(item)
        }

        guard !candidates.isEmpty else { return nil }

        let itemByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let rows = candidates.map { FileListRow(item: $0) }
        let sortedRows = FileListSortEngine.sorted(rows, by: sortSnapshot)
        let sourceItems = sortedRows.compactMap { itemByID[$0.id] }

        guard !sourceItems.isEmpty else { return nil }

        let context = PreviewBrowserContext(
            directoryPath: directoryPath,
            sortSnapshot: sortSnapshot,
            showHiddenFiles: showHiddenFiles,
            sourceItems: sourceItems,
            sameTypeOnly: resolvedSameTypeOnly,
            orderedItems: sourceItems,
            currentIndex: 0
        )
        context.rebuildOrderedItems(keepingFileID: currentFileID)
        return context
    }

    private func rebuildOrderedItems(keepingFileID: String) {
        var items = sourceItems
        if sameTypeOnly,
           let reference = sourceItems.first(where: { $0.id == keepingFileID })
            ?? orderedItems.first(where: { $0.id == keepingFileID }) {
            items = PreviewBrowserEligibility.filterSameType(sourceItems, as: reference)
        }

        guard !items.isEmpty else {
            orderedItems = sourceItems
            currentIndex = sourceItems.firstIndex(where: { $0.id == keepingFileID }) ?? 0
            return
        }

        orderedItems = items
        currentIndex = items.firstIndex(where: { $0.id == keepingFileID }) ?? min(currentIndex, items.count - 1)
    }
}
