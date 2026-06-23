import AppKit
import Foundation
import UniformTypeIdentifiers

/// 缩略图网格的数据源、布局与选择控制器。
public final class FileListThumbnailController: NSObject {
    private(set) var scrollView: NSScrollView?
    private(set) var collectionView: FileListThumbnailCollectionView?
    
    private var sourceRows: [FileListRow] = []
    private(set) var displayRows: [FileListRow] = []
    var selectionGet: (() -> Set<String>)?
    var selectionSet: ((Set<String>) -> Void)?
    private weak var preferencesStore: FileListPreferencesStore?
    var interaction = FileListTableInteraction()
    var lastSearchText = ""
    var lastQuickSearchText = ""
    private var cellSize: CGFloat = FileListThumbnailMetrics.defaultCellSize
    
    private var lastListingSignature = ""
    private var scrollWheelMonitor: Any?
    private var scrollBoundsObserver: NSObjectProtocol?
    private var visibleThumbnailLoadWorkItem: DispatchWorkItem?
    private var pendingDisplayRows: [FileListRow]?
    private var pendingCollectionUpdateWorkItem: DispatchWorkItem?
    private var isPerformingCollectionUpdate = false
    private var hasInstalledCollectionView = false
    private let thumbnailGenerator = ThumbnailGenerator()
    private var directorySizeDisplay: ((String) -> DirectorySizeDisplayInfo)?
    private var lastDirectorySizeRevision: UInt = 0
    private var pendingDirectorySizeRefresh = false
    private var directoryItemCountDisplay: ((String) -> DirectoryItemCountDisplayInfo)?
    private var lastDirectoryItemCountRevision: UInt = 0
    private var pendingDirectoryItemCountRefresh = false
    private var lastReportedVisibleDirectoryPaths: [String] = []
    private var visiblePathsNotifyWorkItem: DispatchWorkItem?
    
    // Interaction state
    var mouseDownIndexPath: IndexPath?
    var mouseDownLocation: NSPoint?
    var mouseDownEvent: NSEvent?
    var mouseDownCanStartFileDrag = false
    var dragSessionActive = false
    var blankMouseDownEvent: NSEvent?
    var blankDragSelecting = false
    var pendingRenameIndexPath: IndexPath?
    var renamingRowID: String?
    var rowRenameEligibleSince: [String: Date] = [:]
    var lastKnownSelectionIDs: Set<String> = []
    var wasAlreadySelectedAtMouseDown = false
    var dropHighlightIndexPath: IndexPath?
    var pendingDropTargetIndexPath: IndexPath?
    var activeDragURLs: [URL]?
    var dropWasPerformed = false
    weak var activeDraggingSession: NSDraggingSession?
    var skipNextItemMouseUp = false
    var usedSystemItemMouseDown = false
    let dragThreshold: CGFloat = 4
    
    var onCellSizeChange: ((CGFloat) -> Void)?
    public var onOpenRow: ((FileListRow) -> Void)?
    public var onVisibleDirectoryPathsChanged: (([String]) -> Void)?
    
    public override init() {
        super.init()
    }
    
    deinit {
        thumbnailGenerator.shutdown()
        tearDownObservers()
    }
    
    // MARK: - Setup
    
    public func makeScrollView() -> NSScrollView {
        let collectionView = FileListThumbnailCollectionView()
        collectionView.interactionController = self
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.allowsEmptySelection = true
        collectionView.backgroundColors = [.textBackgroundColor]
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(UTType.fileURL.identifier),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
        ])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        collectionView.setDraggingSourceOperationMask([.move, .copy], forLocal: false)
        collectionView.register(
            FileListThumbnailItem.self,
            forItemWithIdentifier: FileListThumbnailItem.identifier
        )
        
        applyGridLayout(to: collectionView, cellSize: cellSize)
        
        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        
        self.scrollView = scrollView
        self.collectionView = collectionView
        hasInstalledCollectionView = true
        installObservers()
        return scrollView
    }
    
    public func update(
        rows: [FileListRow],
        interaction: FileListTableInteraction,
        selectionGet: @escaping () -> Set<String>,
        selectionSet: @escaping (Set<String>) -> Void,
        preferencesStore: FileListPreferencesStore,
        cellSize: CGFloat
    ) {
        self.interaction = interaction
        self.selectionGet = selectionGet
        self.selectionSet = selectionSet
        self.preferencesStore = preferencesStore
        collectionView?.servicesRequestor = interaction.servicesRequestor
        
        let normalizedCellSize = FileListThumbnailMetrics.steppedCellSize(from: cellSize)
        let cellSizeChanged = self.cellSize != normalizedCellSize
        if cellSizeChanged {
            self.cellSize = normalizedCellSize
            thumbnailGenerator.cancelInFlightRequests()
            if let collectionView {
                applyGridLayout(to: collectionView, cellSize: normalizedCellSize)
            }
        }
        
        let searchChanged = interaction.searchText != lastSearchText
        let quickSearchChanged = interaction.quickSearchText != lastQuickSearchText
        lastSearchText = interaction.searchText
        lastQuickSearchText = interaction.quickSearchText
        
        let listingSignature = rows.map(\.id).joined(separator: "\u{1F}")
        let listingChanged = listingSignature != lastListingSignature
        if listingChanged {
            lastListingSignature = listingSignature
            lastDirectorySizeRevision = 0
            // 仅取消进行中的 QL 请求；内存/磁盘缓存按 path+mtime 键保留，返回同目录时可即时命中。
            thumbnailGenerator.cancelInFlightRequests()
        }
        
        let previousSourceRows = sourceRows
        let mergedRows: [FileListRow]
        if listingChanged || previousSourceRows.isEmpty {
            mergedRows = rows
        } else {
            mergedRows = mergePreservingDirectoryMetadata(incoming: rows, existing: previousSourceRows)
        }
        sourceRows = mergedRows
        
        let sort = preferencesStore.sort
        let previousDisplayRows = displayRows
        let newDisplay = FileListSortEngine.sorted(mergedRows, by: sort)
        let orderChanged = newDisplay.map(\.id) != previousDisplayRows.map(\.id)
        
        guard hasInstalledCollectionView else {
            displayRows = newDisplay
            sourceRows = mergedRows
            return
        }
        
        if orderChanged || searchChanged || listingChanged || cellSizeChanged {
            pendingDisplayRows = newDisplay
            if listingChanged {
                pendingScrollToTop = true
            }
            scheduleCollectionReload()
        } else {
            displayRows = newDisplay
            if quickSearchChanged {
                scheduleQuickSearchRefresh()
            }
        }
    }
    
    private func scheduleQuickSearchRefresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshVisibleItemAppearance()
            self.scrollToFirstQuickSearchMatchIfNeeded()
        }
    }
    
    private var pendingScrollToTop = false
    
    func refreshDirectorySizeColumnIfNeeded(_ provider: DirectorySizeColumnProvider?) {
        directorySizeDisplay = provider?.display
        guard let provider else { return }
        guard provider.revision != lastDirectorySizeRevision else {
            flushPendingDirectorySizeRefreshIfNeeded()
            return
        }
        lastDirectorySizeRevision = provider.revision
        applyDirectorySizeDisplayUpdates()
    }
    
    func refreshDirectoryItemCountColumnIfNeeded(_ provider: DirectoryItemCountColumnProvider?) {
        directoryItemCountDisplay = provider?.display
        guard let provider else { return }
        guard provider.revision != lastDirectoryItemCountRevision else {
            flushPendingDirectoryItemCountRefreshIfNeeded()
            return
        }
        lastDirectoryItemCountRevision = provider.revision
        applyDirectoryItemCountDisplayUpdates()
    }
    
    private func mergePreservingDirectoryMetadata(
        incoming: [FileListRow],
        existing: [FileListRow]
    ) -> [FileListRow] {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        return incoming.map { row in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            var updated = row
            
            if let directorySizeDisplay {
                let info = directorySizeDisplay(row.iconPath)
                if info != .unknown {
                    updated = updated.withDirectorySizeDisplay(info)
                }
            } else if let cached = existingByID[row.id], cached.sizeDisplay != "--" {
                updated = updated.withDirectorySizeDisplay(
                    DirectorySizeDisplayInfo(sortableSize: cached.size, text: cached.sizeDisplay)
                )
            }
            
            if let directoryItemCountDisplay, !FileListApplicationBundle.isBundle(path: row.iconPath) {
                let info = directoryItemCountDisplay(row.iconPath)
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
    
    private func applyDirectorySizeDisplayUpdates() {
        guard let directorySizeDisplay else { return }
        var changed = false
        displayRows = displayRows.map { row in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            let info = directorySizeDisplay(row.iconPath)
            guard info != .unknown, row.sizeDisplay != info.text else { return row }
            changed = true
            return row.withDirectorySizeDisplay(info)
        }
        sourceRows = sourceRows.map { row in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            let info = directorySizeDisplay(row.iconPath)
            guard info != .unknown, row.sizeDisplay != info.text else { return row }
            changed = true
            return row.withDirectorySizeDisplay(info)
        }
        guard changed else { return }
        pendingDirectorySizeRefresh = true
        flushPendingDirectorySizeRefreshIfNeeded()
    }
    
    private func applyDirectoryItemCountDisplayUpdates() {
        guard let directoryItemCountDisplay else { return }
        var changed = false
        displayRows = displayRows.map { row in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            guard !FileListApplicationBundle.isBundle(path: row.iconPath) else { return row }
            let info = directoryItemCountDisplay(row.iconPath)
            guard info != .unknown, row.childCountDisplay != info.text else { return row }
            changed = true
            return row.withChildCountDisplay(info)
        }
        sourceRows = sourceRows.map { row in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            guard !FileListApplicationBundle.isBundle(path: row.iconPath) else { return row }
            let info = directoryItemCountDisplay(row.iconPath)
            guard info != .unknown, row.childCountDisplay != info.text else { return row }
            changed = true
            return row.withChildCountDisplay(info)
        }
        guard changed else { return }
        pendingDirectoryItemCountRefresh = true
        flushPendingDirectoryItemCountRefreshIfNeeded()
    }
    
    private func flushPendingDirectoryItemCountRefreshIfNeeded() {
        guard pendingDirectoryItemCountRefresh else { return }
        pendingDirectoryItemCountRefresh = false
        refreshVisibleItemAppearance()
    }
    
    private func flushPendingDirectorySizeRefreshIfNeeded() {
        guard pendingDirectorySizeRefresh else { return }
        pendingDirectorySizeRefresh = false
        refreshVisibleItemAppearance()
    }
    
    private func applyGridLayout(to collectionView: NSCollectionView, cellSize: CGFloat) {
        let layout = NSCollectionViewGridLayout()
        let size = NSSize(width: cellSize, height: cellSize)
        layout.minimumItemSize = size
        layout.maximumItemSize = size
        layout.minimumInteritemSpacing = FileListThumbnailMetrics.cellSpacing
        layout.minimumLineSpacing = FileListThumbnailMetrics.cellSpacing
        let inset = FileListThumbnailMetrics.contentInset
        layout.margins = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        collectionView.collectionViewLayout = layout
    }
    
    private func scrollToTop() {
        guard let scrollView, let collectionView else { return }
        let clipView = scrollView.contentView
        let topPoint = NSPoint(x: 0, y: max(0, collectionView.bounds.height - clipView.bounds.height))
        clipView.scroll(to: topPoint)
        scrollView.reflectScrolledClipView(clipView)
    }
    
    private var highlightText: String {
        interaction.quickSearchText.isEmpty ? interaction.searchText : interaction.quickSearchText
    }
    
    private var screenScale: CGFloat {
        collectionView?.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
    }
    
    // MARK: - Collection updates (deferred to avoid layout reentrancy)
    
    private func scheduleCollectionReload() {
        pendingCollectionUpdateWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performCollectionReload()
        }
        pendingCollectionUpdateWorkItem = work
        DispatchQueue.main.async(execute: work)
    }
    
    private func performCollectionReload() {
        guard let collectionView, !isPerformingCollectionUpdate else { return }
        isPerformingCollectionUpdate = true
        defer { isPerformingCollectionUpdate = false }
        
        if let pendingDisplayRows {
            displayRows = pendingDisplayRows
            self.pendingDisplayRows = nil
        }
        
        cancelRenameIfNeededForDataUpdate()
        collectionView.reloadData()
        syncSelectionIndexPathsOnly()
        
        if pendingScrollToTop {
            pendingScrollToTop = false
            scrollToTop()
        }
        
        scheduleVisibleThumbnailLoad()
        scheduleVisibleDirectoryPathsNotify()
    }
    
    // MARK: - Thumbnails
    
    private func scheduleVisibleThumbnailLoad() {
        visibleThumbnailLoadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.loadVisibleThumbnails()
        }
        visibleThumbnailLoadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
    
    private static let visibleThumbnailBatchSize = 8
    
    private func loadVisibleThumbnails() {
        guard let collectionView, !isPerformingCollectionUpdate else { return }
        let indexPaths = collectionView.indexPathsForVisibleItems().sorted { $0.item < $1.item }
        loadThumbnailBatch(indexPaths: indexPaths, startIndex: 0)
    }
    
    private func loadThumbnailBatch(indexPaths: [IndexPath], startIndex: Int) {
        guard let collectionView, !isPerformingCollectionUpdate else { return }
        let end = min(startIndex + Self.visibleThumbnailBatchSize, indexPaths.count)
        for index in startIndex..<end {
            let indexPath = indexPaths[index]
            guard let item = collectionView.item(at: indexPath) as? FileListThumbnailItem,
                  indexPath.item >= 0,
                  indexPath.item < displayRows.count else { continue }
            let row = displayRows[indexPath.item]
            guard item.representedRowID == row.id, !item.hasLoadedContent else { continue }
            enqueueThumbnailLoad(for: item, row: row)
        }
        guard end < indexPaths.count else { return }
        DispatchQueue.main.async { [weak self] in
            self?.loadThumbnailBatch(indexPaths: indexPaths, startIndex: end)
        }
    }
    
    /// 仅配置占位与选中态，不做磁盘 I/O 或 QL 生成。
    private func prepareThumbnailItem(_ item: FileListThumbnailItem, row: FileListRow) {
        _ = item.beginLoad(for: row.id)
        
        if let cached = thumbnailGenerator.cachedImage(for: row, cellSize: cellSize) {
            let displayImage = cached.isThumbnail
                ? cached.image
                : FileListThumbnailMetrics.scaledIcon(cached.image, cellSize: cellSize)
            item.configure(
                row: row,
                isSelected: isRowSelected(row.id),
                highlightText: highlightText,
                placeholderImage: displayImage,
                cellSize: cellSize
            )
            item.applyLoadedImage(displayImage, isThumbnail: cached.isThumbnail, animated: false)
            return
        }
        
        let placeholder = thumbnailGenerator.instantPlaceholder(
            for: row,
            cellSize: cellSize,
            screenScale: screenScale
        )
        item.configure(
            row: row,
            isSelected: isRowSelected(row.id),
            highlightText: highlightText,
            placeholderImage: placeholder,
            cellSize: cellSize
        )
    }
    
    private func enqueueThumbnailLoad(for item: FileListThumbnailItem, row: FileListRow) {
        if row.isParentDirectoryEntry {
            let icon = thumbnailGenerator.instantPlaceholder(
                for: row,
                cellSize: cellSize,
                screenScale: screenScale
            )
            item.applyLoadedImage(icon, isThumbnail: false, animated: false)
            return
        }
        
        let token = item.loadToken
        thumbnailGenerator.load(
            for: row,
            cellSize: cellSize,
            screenScale: screenScale
        ) { [weak item] delivery in
            guard let item else { return }
            guard item.loadToken == token, item.representedRowID == row.id else { return }
            switch delivery {
            case .thumbnail(let image):
                item.applyLoadedImage(image, isThumbnail: true, animated: true)
            case .icon(let image):
                item.applyLoadedImage(image, isThumbnail: false, animated: false)
            }
        }
    }
    
    private func isRowSelected(_ rowID: String) -> Bool {
        effectiveSelectionIDs().contains(rowID)
    }
    
    func refreshVisibleItemAppearance() {
        guard let collectionView, !isPerformingCollectionUpdate else { return }
        for indexPath in collectionView.indexPathsForVisibleItems() {
            guard let item = collectionView.item(at: indexPath) as? FileListThumbnailItem,
                  indexPath.item >= 0,
                  indexPath.item < displayRows.count else { continue }
            let row = displayRows[indexPath.item]
            item.updateSelection(isRowSelected(row.id), highlightText: highlightText, row: row)
            if item.representedRowID == row.id {
                item.refreshRowMetadata(row)
            }
        }
    }
    
    // MARK: - Selection
    
    private func syncSelectionIndexPathsOnly() {
        guard let collectionView, let selectionGet, let selectionSet else { return }
        let selected = selectionGet()
        let collectionSelectedIDs = Set(
            collectionView.selectionIndexPaths.compactMap { indexPath -> String? in
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return nil }
                return displayRows[indexPath.item].id
            }
        )
        if selected.isEmpty, !collectionSelectedIDs.isEmpty {
            selectionSet(collectionSelectedIDs)
            return
        }
        
        var indexPaths = Set<IndexPath>()
        for (index, row) in displayRows.enumerated() where selected.contains(row.id) {
            indexPaths.insert(IndexPath(item: index, section: 0))
        }
        if collectionView.selectionIndexPaths != indexPaths {
            collectionView.selectionIndexPaths = indexPaths
        }
    }
    
    func syncSelectionToCollection() {
        syncSelectionIndexPathsOnly()
        refreshVisibleItemAppearance()
    }
    
    func syncSelectionFromCollection() {
        guard let collectionView, let selectionGet, let selectionSet else { return }
        let ids = Set(
            collectionView.selectionIndexPaths.compactMap { indexPath -> String? in
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return nil }
                return displayRows[indexPath.item].id
            }
        )
        if selectionGet() != ids {
            selectionSet(ids)
        }
        recordRenameSelectionTimestamps()
        refreshVisibleItemAppearance()
    }
    
    private func scrollToFirstQuickSearchMatchIfNeeded() {
        guard let collectionView else { return }
        let keyword = interaction.quickSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        guard let index = displayRows.firstIndex(where: {
            !$0.isParentDirectoryEntry &&
            $0.name.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: .current
            ) != nil
        }) else { return }
        
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredVertically)
        collectionView.selectionIndexPaths = [indexPath]
        syncSelectionFromCollection()
    }
    
    func effectiveSelectionIDs() -> Set<String> {
        if let selectionGet {
            let selected = selectionGet()
            if !selected.isEmpty { return selected }
        }
        guard let collectionView else { return [] }
        return Set(
            collectionView.selectionIndexPaths.compactMap { indexPath -> String? in
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return nil }
                return displayRows[indexPath.item].id
            }
        )
    }
    
    // MARK: - Actions
    
    func openSelectedRow() {
        guard let collectionView,
              let indexPath = collectionView.selectionIndexPaths.sorted(by: { $0.item < $1.item }).first,
              indexPath.item >= 0,
              indexPath.item < displayRows.count else { return }
        onOpenRow?(displayRows[indexPath.item])
    }
    
    func openRow(at indexPath: IndexPath) {
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return }
        onOpenRow?(displayRows[indexPath.item])
    }
    
    // MARK: - Visible directories
    
    private func scheduleVisibleDirectoryPathsNotify() {
        visiblePathsNotifyWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.notifyVisibleDirectoryPathsIfNeeded()
        }
        visiblePathsNotifyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }
    
    private func notifyVisibleDirectoryPathsIfNeeded() {
        guard let onVisibleDirectoryPathsChanged else { return }
        guard let collectionView else { return }
        let paths = collectionView.indexPathsForVisibleItems()
            .compactMap { indexPath -> String? in
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return nil }
                let row = displayRows[indexPath.item]
                guard row.isDirectory, !row.isParentDirectoryEntry else { return nil }
                return row.iconPath
            }
        let unique = Array(Set(paths)).sorted()
        guard unique != lastReportedVisibleDirectoryPaths else { return }
        lastReportedVisibleDirectoryPaths = unique
        onVisibleDirectoryPathsChanged(unique)
    }
    
    func indexPath(for rowID: String) -> IndexPath? {
        guard let index = displayRows.firstIndex(where: { $0.id == rowID }) else { return nil }
        return IndexPath(item: index, section: 0)
    }
    
    func thumbnailItem(at indexPath: IndexPath) -> FileListThumbnailItem? {
        collectionView?.item(at: indexPath) as? FileListThumbnailItem
    }
    
    func gridColumnCount() -> Int {
        guard let collectionView else { return 1 }
        let inset = FileListThumbnailMetrics.contentInset
        let availableWidth = max(cellSize, collectionView.bounds.width - inset * 2)
        let stride = cellSize + FileListThumbnailMetrics.cellSpacing
        return max(1, Int(floor((availableWidth + FileListThumbnailMetrics.cellSpacing) / stride)))
    }
    
    // MARK: - Observers
    
    private func installObservers() {
        scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let collectionView = self.collectionView else { return event }
            guard event.window === collectionView.window else { return event }
            guard collectionView.window?.firstResponder === collectionView else { return event }
            guard event.modifierFlags.contains(.command) else { return event }
            
            let delta = event.scrollingDeltaY
            guard abs(delta) > 0.5 else { return event }
            let direction: CGFloat = delta > 0 ? 1 : -1
            let next = FileListThumbnailMetrics.steppedCellSize(
                from: self.cellSize + direction * FileListThumbnailMetrics.cellSizeStep
            )
            guard next != self.cellSize else { return event }
            self.cellSize = next
            self.thumbnailGenerator.cancelInFlightRequests()
            self.applyGridLayout(to: collectionView, cellSize: next)
            DispatchQueue.main.async {
                self.onCellSizeChange?(next)
                self.scheduleCollectionReload()
            }
            return nil
        }
        
        if let scrollView {
            scrollBoundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.scheduleVisibleThumbnailLoad()
                self.scheduleVisibleDirectoryPathsNotify()
            }
            scrollView.contentView.postsBoundsChangedNotifications = true
        }
    }
    
    private func tearDownObservers() {
        if let scrollWheelMonitor {
            NSEvent.removeMonitor(scrollWheelMonitor)
            self.scrollWheelMonitor = nil
        }
        if let scrollBoundsObserver {
            NotificationCenter.default.removeObserver(scrollBoundsObserver)
            self.scrollBoundsObserver = nil
        }
    }
}

// MARK: - NSCollectionViewDataSource

extension FileListThumbnailController: NSCollectionViewDataSource {
    public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        displayRows.count
    }
    
    public func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: FileListThumbnailItem.identifier,
            for: indexPath
        ) as! FileListThumbnailItem
        guard indexPath.item >= 0, indexPath.item < displayRows.count else { return item }
        prepareThumbnailItem(item, row: displayRows[indexPath.item])
        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension FileListThumbnailController: NSCollectionViewDelegate {
    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        syncSelectionFromCollection()
    }
    
    public func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        syncSelectionFromCollection()
    }
}