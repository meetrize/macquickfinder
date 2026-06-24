import AppKit
import Foundation
import UniformTypeIdentifiers

/// 缩略图网格的数据源、布局与选择控制器。
public final class FileListThumbnailController: FileListContentController {
    private(set) var collectionView: FileListThumbnailCollectionView?
    
    private var cellSize: CGFloat = FileListThumbnailMetrics.defaultCellSize
    
    private var scrollWheelMonitor: Any?
    private var scrollBoundsObserver: NSObjectProtocol?
    private var memoryPressureObserver: NSObjectProtocol?
    private var visibleThumbnailLoadWorkItem: DispatchWorkItem?
    private var pendingDisplayRows: [FileListRow]?
    private var pendingCollectionUpdateWorkItem: DispatchWorkItem?
    private var isPerformingCollectionUpdate = false
    private var pendingCollectionReloadFull = false
    private var hasInstalledCollectionView = false
    private let thumbnailGenerator = ThumbnailGenerator()
    
    // Interaction state
    var mouseDownIndexPath: IndexPath?
    var pendingRenameIndexPath: IndexPath?
    var dropHighlightIndexPath: IndexPath?
    var pendingDropTargetIndexPath: IndexPath?
    var activeDragURLs: [URL]?
    var dropWasPerformed = false
    weak var activeDraggingSession: NSDraggingSession?
    var skipNextItemMouseUp = false
    var usedSystemItemMouseDown = false
    var onCellSizeChange: ((CGFloat) -> Void)?
    
    private(set) var scrollView: NSScrollView?
    
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
        FileListDragDropRegistration.registerDragTypes(on: collectionView)
        FileListDragDropRegistration.configureSourceMasks(on: collectionView)
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
        bindUpdateContext(
            interaction: interaction,
            selectionGet: selectionGet,
            selectionSet: selectionSet,
            preferencesStore: preferencesStore
        )
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
        
        let plan = prepareListingUpdate(
            rows: rows,
            metadataProviders: .init(
                directorySize: directorySizeDisplay,
                directoryItemCount: directoryItemCountDisplay
            )
        )
        if plan.listingChanged {
            thumbnailGenerator.cancelInFlightRequests()
            thumbnailGenerator.clearMemoryCache()
            if renamingRowID != nil {
                cancelRenameIfNeededForDataUpdate()
            }
        }
        
        guard hasInstalledCollectionView else { return }
        
        if plan.orderChanged || plan.searchChanged || plan.listingChanged || cellSizeChanged {
            pendingDisplayRows = plan.sortedDisplayRows
            pendingCollectionReloadFull = plan.listingChanged || cellSizeChanged
            if plan.listingChanged {
                pendingScrollToTop = true
            }
            scheduleCollectionReload()
        } else {
            if plan.quickSearchChanged {
                scheduleQuickSearchRefresh()
            } else if plan.displayUnchanged {
                scheduleVisibleDirectoryPathsNotify(debounce: 0.08)
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

    private func applyDirectorySizeDisplayUpdates() {
        guard let directorySizeDisplay else { return }
        if isUserPointerActive {
            pendingDirectorySizeRefresh = true
            return
        }
        pendingDirectorySizeRefresh = false
        let result = FileListDirectoryMetadataRefresh.applySizeDisplayUpdates(
            sourceRows: sourceRows,
            displayRows: displayRows,
            display: directorySizeDisplay
        )
        guard result.changed else { return }
        sourceRows = result.sourceRows
        displayRows = result.displayRows
        refreshVisibleItemAppearance()
    }

    private func applyDirectoryItemCountDisplayUpdates() {
        guard let directoryItemCountDisplay else { return }
        if isUserPointerActive {
            pendingDirectoryItemCountRefresh = true
            return
        }
        pendingDirectoryItemCountRefresh = false
        let result = FileListDirectoryMetadataRefresh.applyItemCountDisplayUpdates(
            sourceRows: sourceRows,
            displayRows: displayRows,
            display: directoryItemCountDisplay
        )
        guard result.changed else { return }
        sourceRows = result.sourceRows
        displayRows = result.displayRows
        refreshVisibleItemAppearance()
    }

    func flushPendingDirectoryItemCountRefreshIfNeeded() {
        guard pendingDirectoryItemCountRefresh else { return }
        applyDirectoryItemCountDisplayUpdates()
    }

    func flushPendingDirectorySizeRefreshIfNeeded() {
        guard pendingDirectorySizeRefresh else { return }
        applyDirectorySizeDisplayUpdates()
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
        if pendingCollectionReloadFull {
            collectionView.reloadData()
        } else {
            let indexPaths = Set(displayRows.indices.map { IndexPath(item: $0, section: 0) })
            if indexPaths.isEmpty {
                collectionView.reloadData()
            } else {
                collectionView.reloadItems(at: indexPaths)
            }
        }
        pendingCollectionReloadFull = false
        syncSelectionIndexPathsOnly()
        
        if pendingScrollToTop {
            pendingScrollToTop = false
            scrollToTop()
        }
        
        scheduleVisibleThumbnailLoad()
        scheduleVisibleDirectoryPathsNotify(debounce: 0.08)
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
    
    /// 仅配置占位与选中态；磁盘缓存命中由 `enqueueThumbnailLoad` 异步回填。
    private func prepareThumbnailItem(_ item: FileListThumbnailItem, row: FileListRow) {
        _ = item.beginLoad(for: row.id)
        
        let memoryCached = thumbnailGenerator.memoryCachedImage(for: row, cellSize: cellSize)
        let placeholder: NSImage
        if let cached = memoryCached {
            placeholder = cached.isThumbnail
                ? cached.image
                : FileListThumbnailMetrics.scaledIcon(cached.image, cellSize: cellSize)
        } else {
            placeholder = thumbnailGenerator.instantPlaceholder(
                for: row,
                cellSize: cellSize,
                screenScale: screenScale
            )
        }
        
        item.configure(
            row: row,
            isSelected: isRowSelected(row.id),
            highlightText: highlightText,
            placeholderImage: placeholder,
            cellSize: cellSize
        )
        
        if let cached = memoryCached {
            let displayImage = cached.isThumbnail
                ? cached.image
                : FileListThumbnailMetrics.scaledIcon(cached.image, cellSize: cellSize)
            item.applyLoadedImage(displayImage, isThumbnail: cached.isThumbnail, animated: false)
        }
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
        guard let collectionView, let index = firstQuickSearchMatchIndex() else { return }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredVertically)
        collectionView.selectionIndexPaths = [indexPath]
        syncSelectionFromCollection()
    }
    
    func effectiveSelectionIDs() -> Set<String> {
        let collectionSelectedIDs = Set(
            (collectionView?.selectionIndexPaths ?? []).compactMap { indexPath -> String? in
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return nil }
                return displayRows[indexPath.item].id
            }
        )
        return FileListInteractionCoordinator.collectionEffectiveSelectionIDs(
            selectionGet: selectionGet,
            collectionSelectedIDs: collectionSelectedIDs
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
    
    override func visibleDirectoryPaths() -> [String] {
        guard let collectionView else { return [] }
        let paths = collectionView.indexPathsForVisibleItems()
            .compactMap { indexPath -> String? in
                guard indexPath.item >= 0, indexPath.item < displayRows.count else { return nil }
                let row = displayRows[indexPath.item]
                guard row.isDirectory, !row.isParentDirectoryEntry else { return nil }
                return row.iconPath
            }
        return Array(Set(paths)).sorted()
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
                self.pendingCollectionReloadFull = true
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
                self.scheduleVisibleDirectoryPathsNotify(debounce: 0.08)
            }
            scrollView.contentView.postsBoundsChangedNotifications = true
        }

        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: .meoFindMemoryPressure,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thumbnailGenerator.clearMemoryCache()
            self?.thumbnailGenerator.trimDiskCache()
        }
    }
    
    private func tearDownObservers() {
        if let memoryPressureObserver {
            NotificationCenter.default.removeObserver(memoryPressureObserver)
            self.memoryPressureObserver = nil
        }
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