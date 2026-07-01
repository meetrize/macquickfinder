import AppKit
import Foundation
import UniformTypeIdentifiers

/// 列表模式与缩略图模式共享的行状态、搜索追踪、重命名与指针会话状态。
public class FileListContentController: NSObject {
    var sourceRows: [FileListRow] = []
    var displayRows: [FileListRow] = []
    var selectionGet: (() -> Set<String>)?
    var selectionSet: ((Set<String>) -> Void)?
    weak var preferencesStore: FileListPreferencesStore?
    var interaction = FileListTableInteraction()

    var lastSearchText = ""
    var lastQuickSearchText = ""
    var lastListingSignatureHash = 0

    let renameCoordinator = FileListRenameCoordinator()
    let dragThreshold = FileListInteractionCoordinator.dragThreshold

    var mouseDownLocation: NSPoint?
    var mouseDownEvent: NSEvent?
    var mouseDownCanStartFileDrag = false
    var dragSessionActive = false
    var blankMouseDownEvent: NSEvent?
    var blankDragSelecting = false
    var wasAlreadySelectedAtMouseDown = false

    var directorySizeDisplay: ((String) -> DirectorySizeDisplayInfo)?
    var lastDirectorySizeRevision: UInt = 0
    var pendingDirectorySizeRefresh = false

    var directoryItemCountDisplay: ((String) -> DirectoryItemCountDisplayInfo)?
    var lastDirectoryItemCountRevision: UInt = 0
    var pendingDirectoryItemCountRefresh = false

    public var onOpenRow: ((FileListRowOpenIntent) -> Void)?
    public var onVisibleDirectoryPathsChanged: (([String]) -> Void)?

    var visiblePathsNotifyWorkItem: DispatchWorkItem?
    var lastReportedVisibleDirectoryPaths: [String] = []

    var renamingRowID: String? {
        get { renameCoordinator.renamingRowID }
        set { renameCoordinator.renamingRowID = newValue }
    }

    var isRenaming: Bool { renameCoordinator.isRenaming }

    var isUserPointerActive: Bool {
        dragSessionActive
            || blankDragSelecting
            || mouseDownEvent != nil
            || blankMouseDownEvent != nil
    }

    // MARK: - Update pipeline (shared)

    struct ListingUpdatePlan {
        let searchChanged: Bool
        let quickSearchChanged: Bool
        let listingChanged: Bool
        let mergedSourceRows: [FileListRow]
        let sortedDisplayRows: [FileListRow]
        let orderChanged: Bool
        let displayUnchanged: Bool
    }

    func bindUpdateContext(
        interaction: FileListTableInteraction,
        selectionGet: @escaping () -> Set<String>,
        selectionSet: @escaping (Set<String>) -> Void,
        preferencesStore: FileListPreferencesStore
    ) {
        self.interaction = interaction
        self.selectionGet = selectionGet
        self.selectionSet = selectionSet
        self.preferencesStore = preferencesStore
    }

    func prepareListingUpdate(
        rows: [FileListRow],
        metadataProviders: FileListDirectoryMetadataRefresh.Providers
    ) -> ListingUpdatePlan {
        let searchChanged = interaction.searchText != lastSearchText
        lastSearchText = interaction.searchText
        let quickSearchChanged = interaction.quickSearchText != lastQuickSearchText
        lastQuickSearchText = interaction.quickSearchText

        let listingHash = FileListListingSignature.hash(for: rows)
        let listingChanged = listingHash != lastListingSignatureHash
        if listingChanged {
            lastListingSignatureHash = listingHash
            lastDirectorySizeRevision = 0
            lastDirectoryItemCountRevision = 0
        }

        let previousSourceRows = sourceRows
        let mergedRows: [FileListRow]
        if listingChanged || previousSourceRows.isEmpty {
            mergedRows = rows
        } else {
            mergedRows = FileListDirectoryMetadataRefresh.mergePreservingMetadata(
                incoming: rows,
                existing: previousSourceRows,
                providers: metadataProviders
            )
        }
        sourceRows = mergedRows

        let sort = preferencesStore?.sort ?? FileListSortState.default
        let previousDisplayRows = displayRows
        let newDisplay = FileListSortEngine.sorted(mergedRows, by: sort)
        let orderChanged = newDisplay.map(\.id) != previousDisplayRows.map(\.id)
        let displayUnchanged = !orderChanged
            && !searchChanged
            && !quickSearchChanged
            && !listingChanged
            && newDisplay == previousDisplayRows

        displayRows = newDisplay
        if orderChanged {
            lastReportedVisibleDirectoryPaths = []
        }

        return ListingUpdatePlan(
            searchChanged: searchChanged,
            quickSearchChanged: quickSearchChanged,
            listingChanged: listingChanged,
            mergedSourceRows: mergedRows,
            sortedDisplayRows: newDisplay,
            orderChanged: orderChanged,
            displayUnchanged: displayUnchanged
        )
    }

    func setDisplayRows(_ rows: [FileListRow]) {
        displayRows = rows
    }

    // MARK: - Quick search

    func quickSearchKeyword() -> String? {
        let keyword = interaction.quickSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return nil }
        return keyword
    }

    func rowMatchesQuickSearch(_ row: FileListRow, keyword: String) -> Bool {
        !row.isParentDirectoryEntry
            && row.name.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: .current
            ) != nil
    }

    func quickSearchMatchIndices() -> [Int] {
        guard let keyword = quickSearchKeyword() else { return [] }
        return displayRows.indices.filter { rowMatchesQuickSearch(displayRows[$0], keyword: keyword) }
    }

    func firstQuickSearchMatchIndex() -> Int? {
        quickSearchMatchIndices().first
    }

    func currentSelectedDisplayRowIndex() -> Int? {
        guard let selectionGet else { return nil }
        let selected = selectionGet()
        for id in selected {
            if let index = displayRows.firstIndex(where: { $0.id == id }) {
                return index
            }
        }
        return nil
    }

    public func cycleQuickSearchMatch(forward: Bool) {
        let matches = quickSearchMatchIndices()
        guard matches.count > 1 else { return }
        let current = currentSelectedDisplayRowIndex()
        guard let row = FileListInteractionCoordinator.nextQuickSearchMatchIndex(
            in: matches,
            from: current,
            forward: forward
        ) else { return }
        applyQuickSearchMatchFocus(at: row)
    }

    func scrollToFirstQuickSearchMatchIfNeeded() {
        guard let row = firstQuickSearchMatchIndex() else { return }
        applyQuickSearchMatchFocus(at: row)
    }

    func applyQuickSearchMatchFocus(at row: Int) {
        _ = row
    }

    // MARK: - Visible directory paths

    func scheduleVisibleDirectoryPathsNotify(debounce: TimeInterval = 0.12) {
        visiblePathsNotifyWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reportVisibleDirectoryPathsIfNeeded()
        }
        visiblePathsNotifyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    func reportVisibleDirectoryPathsIfNeeded() {
        guard onVisibleDirectoryPathsChanged != nil else { return }
        let paths = visibleDirectoryPaths()
        guard paths != lastReportedVisibleDirectoryPaths else { return }
        lastReportedVisibleDirectoryPaths = paths
        onVisibleDirectoryPathsChanged?(paths)
    }

    func visibleDirectoryPaths() -> [String] {
        []
    }

    func isDropInsideHostWindow(screenPoint: NSPoint) -> Bool {
        FileListDragDropSupport.isScreenPointInsideWindow(screenPoint, window: hostWindowForDropHitTest())
    }

    func hostWindowForDropHitTest() -> NSWindow? {
        nil
    }

    // MARK: - Pointer session cleanup (subclass extends)

    func clearBlankDragState() {
        if blankDragSelecting || dragSessionActive {
            FileListContentInteractionNotifier.notifyDidEnd()
        }
        blankMouseDownEvent = nil
        blankDragSelecting = false
        mouseDownCanStartFileDrag = false
    }

    func noteDragSessionEnded(performingDrop: Bool) {
        dragSessionActive = false
        FileListContentInteractionNotifier.notifyDidEnd()
        mouseDownLocation = nil
        mouseDownEvent = nil
        mouseDownCanStartFileDrag = false
        if performingDrop {
            DispatchQueue.main.async { [weak self] in
                self?.interaction.onDragEnded()
            }
        }
    }

}

enum FileListDragDropRegistration {
    static let fileURLPasteboardTypes: [NSPasteboard.PasteboardType] = FileListExternalFileDrag.pasteboardTypes

    static func registerDragTypes(on view: NSView) {
        view.registerForDraggedTypes(fileURLPasteboardTypes)
    }

    static func configureSourceMasks(on view: NSView) {
        if let collectionView = view as? NSCollectionView {
            collectionView.setDraggingSourceOperationMask(.move, forLocal: true)
            collectionView.setDraggingSourceOperationMask(.every, forLocal: false)
        } else if let tableView = view as? NSTableView {
            tableView.setDraggingSourceOperationMask(.move, forLocal: true)
            tableView.setDraggingSourceOperationMask(.every, forLocal: false)
        }
    }
}
