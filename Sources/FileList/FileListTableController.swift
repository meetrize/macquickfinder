import AppKit
import Foundation
import UniformTypeIdentifiers

/// NSTableView 数据源、列配置、排序与表头交互的统一控制器。
public final class FileListTableController: FileListContentController {
    public static weak var shared: FileListTableController?

    private(set) var scrollView: NSScrollView?
    private(set) var tableView: NSTableView?

    var mouseDownRow = -1
    var mouseDownHandledByDisclosureToggle = false
    var dropHighlightRow: Int?
    var hoverHighlightRow: Int?
    var _rowHoverHighlightEnabled = false
    var pendingRenameRow = -1
    var skipRenameArmOnCurrentMouseUp = false

    var columnResizeObserver: NSObjectProtocol?
    var columnMoveObserver: NSObjectProtocol?
    var scrollBoundsObserver: NSObjectProtocol?
    var memoryPressureObserver: NSObjectProtocol?
    var headerRightClickMonitor: Any?
    var widthSaveWorkItem: DispatchWorkItem?
    var paddingAfterResizeWorkItem: DispatchWorkItem?
    var isApplyingColumnLayout = false
    var isUpdatingPaddingColumn = false
    var pendingPaddingLayout = false
    var lastColumnStructureToken = ""
    var lastFillLayoutRowCount = -1
    var lastFillLayoutClipHeight: CGFloat = -1
    var lastFillLayoutClipWidth: CGFloat = -1
    var pendingScrollToTop = false
    var contentBackgroundMaxX: CGFloat = 0

    var useIconPreview = false
    let thumbnailGenerator = ThumbnailGenerator.shared
    var visibleIconPreviewLoadWorkItem: DispatchWorkItem?

    let userResizing = NSTableColumn.ResizingOptions(rawValue: 1 << 1)

    public override init() {
        super.init()
        FileListTableController.shared = self
    }

    deinit {
        tearDownObservers()
    }

    // MARK: - Setup

    public func makeScrollView() -> NSScrollView {
        let tableView = FileListTableView()
        tableView.interactionController = self
        tableView.style = .fullWidth
        tableView.rowHeight = 22
        tableView.intercellSpacing = NSSize(width: 6, height: 0)
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick(_:))
        FileListDragDropRegistration.registerDragTypes(on: tableView)
        FileListDragDropRegistration.configureSourceMasks(on: tableView)

        let header = FileListTableHeaderView()
        header.clickHandler = self
        tableView.headerView = header

        for columnID in FileListColumnID.allCases {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(columnID.rawValue))
            column.title = columnID.headerTitle
            column.headerCell = FileListSortableHeaderCell(title: columnID.headerTitle)
            column.minWidth = columnID.minWidth
            column.maxWidth = columnID.maxWidth
            column.resizingMask = userResizing
            tableView.addTableColumn(column)
        }
        tableView.addTableColumn(FileListPaddingColumn.makeColumn())

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = tableView

        self.tableView = tableView
        self.scrollView = scrollView

        (tableView as? FileListTableView)?.installRowHoverTrackingIfNeeded()
        installObservers()
        ensureTableViewFillsClipViewIfNeeded()
        return scrollView
    }

    public func update(
        rows: [FileListRow],
        interaction: FileListTableInteraction,
        selectionGet: @escaping () -> Set<String>,
        selectionSet: @escaping (Set<String>) -> Void,
        preferencesStore: FileListPreferencesStore,
        useIconPreview: Bool = false,
        rowHoverHighlight: Bool = false
    ) {
        let iconPreviewChanged = self.useIconPreview != useIconPreview
        self.useIconPreview = useIconPreview
        if iconPreviewChanged && !useIconPreview {
            thumbnailGenerator.cancelInFlightRequests()
        }
        rowHoverHighlightEnabled = rowHoverHighlight

        bindUpdateContext(
            interaction: interaction,
            selectionGet: selectionGet,
            selectionSet: selectionSet,
            preferencesStore: preferencesStore
        )
        (tableView as? FileListTableView)?.servicesRequestor = interaction.servicesRequestor

        let structureToken = columnStructureToken(from: preferencesStore.configuration)
        if structureToken != lastColumnStructureToken {
            lastColumnStructureToken = structureToken
            applyColumnLayout(from: preferencesStore.configuration, full: true)
        }

        let previousDisplayRows = displayRows
        let plan = prepareListingUpdate(
            rows: rows,
            metadataProviders: .init(
                directorySize: directorySizeDisplay,
                directoryItemCount: nil
            )
        )
        if plan.listingChanged {
            thumbnailGenerator.cancelInFlightRequests()
            thumbnailGenerator.clearMemoryCache()
            if renamingRowID != nil {
                cancelRenameIfNeededForDataUpdate()
            }
        }

        let newDisplay = plan.sortedDisplayRows
        let sizeOnlyChanged = !plan.orderChanged
            && !plan.searchChanged
            && !plan.listingChanged
            && newDisplay.count == previousDisplayRows.count
            && zip(newDisplay, previousDisplayRows).allSatisfy { $0.hasSameStaticContent(as: $1) }
            && zip(newDisplay, previousDisplayRows).contains { $0.size != $1.size || $0.sizeDisplay != $1.sizeDisplay }

        if plan.displayUnchanged {
            if iconPreviewChanged {
                FileListTableAnimations.performWithoutAnimation {
                    tableView?.reloadData()
                }
            }
            scheduleVisibleDirectoryPathsNotify(debounce: 0.15)
            if useIconPreview {
                scheduleVisibleIconPreviewLoad()
            }
            return
        }

        let sort = preferencesStore.sort
        if iconPreviewChanged {
            lastFillLayoutRowCount = -1
            FileListTableAnimations.performWithoutAnimation {
                tableView?.reloadData()
            }
        } else if plan.orderChanged || plan.searchChanged {
            lastFillLayoutRowCount = -1
            FileListTableAnimations.performWithoutAnimation {
                if plan.orderChanged && !plan.searchChanged && !plan.listingChanged {
                    reloadDataPreservingVisibleRowAnchor(previousRows: previousDisplayRows)
                } else {
                    tableView?.reloadData()
                }
                updateSortIndicators(for: sort)
                if plan.listingChanged {
                    pendingScrollToTop = true
                    scrollToTop()
                }
            }
        } else if sizeOnlyChanged {
            reloadSizeColumnPreservingScroll()
        }
        updateSortIndicators(for: sort)

        schedulePaddingColumnLayout()
        if plan.orderChanged || plan.searchChanged || plan.listingChanged {
            syncSelectionToTable()
        }
        if plan.quickSearchChanged {
            refreshVisibleNameLabels()
            // 须在 updateNSView 之外同步选中，否则 SwiftUI 可能忽略 selection 更新，预览面板不刷新。
            scheduleQuickSearchMatchFocus()
        }
        scheduleVisibleDirectoryPathsNotify(debounce: 0.15)
        if useIconPreview {
            scheduleVisibleIconPreviewLoad()
        }
    }

    func finishPointerInteractionIfNeeded() {
        if pendingRenameRow >= 0 {
            let row = pendingRenameRow
            pendingRenameRow = -1
            beginRename(row: row)
        }
        mouseDownEvent = nil
        mouseDownRow = -1
        mouseDownLocation = nil
        mouseDownCanStartFileDrag = false
        blankDragSelecting = false
        flushPendingDirectorySizeRefreshIfNeeded()
    }

    func reloadSizeColumnPreservingScroll() {
        guard let tableView, let scrollView, !displayRows.isEmpty else { return }
        let clipView = scrollView.contentView
        let savedOrigin = clipView.bounds.origin

        FileListTableAnimations.performWithoutAnimation {
            if let sizeColumnIndex = sizeColumnIndex(in: tableView) {
                tableView.reloadData(
                    forRowIndexes: IndexSet(integersIn: 0..<displayRows.count),
                    columnIndexes: IndexSet(integer: sizeColumnIndex)
                )
            }
            clipView.bounds.origin = savedOrigin
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    func reloadDataPreservingVisibleRowAnchor(previousRows: [FileListRow]) {
        guard let tableView, !previousRows.isEmpty else {
            tableView?.reloadData()
            return
        }
        let visible = tableView.rows(in: tableView.visibleRect)
        let anchorRow = min(max(visible.location, 0), previousRows.count - 1)
        let anchorID = previousRows[anchorRow].id

        tableView.reloadData()

        guard let newRow = displayRows.firstIndex(where: { $0.id == anchorID }) else { return }
        tableView.scrollRowToVisible(newRow)
    }

    override func visibleDirectoryPaths() -> [String] {
        guard let tableView else { return [] }
        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return [] }
        var paths: [String] = []
        paths.reserveCapacity(visible.length)
        for row in visible.location..<(visible.location + visible.length) {
            let item = displayRows[row]
            guard item.isDirectory, !item.isParentDirectoryEntry else { continue }
            paths.append(item.iconPath)
        }
        return paths
    }

    func refreshVisibleRowContentClip() {
        invalidateVisibleRowHighlights()
    }

    /// 列宽拖拽过程中强制重绘可见行（columnDidResize 仅在松开时触发）。
    func invalidateVisibleRowHighlights() {
        guard let tableView else { return }
        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return }
        for row in visible.location..<(visible.location + visible.length) {
            tableView.rowView(atRow: row, makeIfNecessary: true)?.needsDisplay = true
        }
    }

    // MARK: - Sort

    func handleHeaderSortClick(columnID: FileListColumnID) {
        guard let preferencesStore else { return }
        var sort = preferencesStore.sort
        if sort.column == columnID {
            sort.ascending.toggle()
        } else {
            sort.column = columnID
            sort.ascending = FileListSortEngine.defaultAscending(for: columnID)
        }
        preferencesStore.updateSort(sort)

        displayRows = FileListSortEngine.sorted(sourceRows, by: sort)
        FileListTableAnimations.performWithoutAnimation {
            tableView?.reloadData()
            updateSortIndicators(for: sort)
        }
        syncSelectionToTable()
    }

    func updateSortIndicators(for sort: FileListSortState) {
        guard let tableView else { return }
        for column in tableView.tableColumns {
            guard let columnID = FileListColumnID.from(column: column) else { continue }
            let title = columnID.headerTitle
            if let sortableHeaderCell = column.headerCell as? FileListSortableHeaderCell {
                sortableHeaderCell.baseTitle = title
                sortableHeaderCell.sortIndicator = (columnID == sort.column)
                    ? (sort.ascending ? "↑" : "↓")
                    : nil
                sortableHeaderCell.title = title
            } else if columnID == sort.column {
                column.headerCell.title = title + (sort.ascending ? " ↑" : " ↓")
            } else {
                column.headerCell.title = title
            }
        }
        tableView.headerView?.needsDisplay = true
    }

    @objc func handleDoubleClick(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < displayRows.count else { return }
        onOpenRow?(displayRows[row])
    }

    // MARK: - Selection

    func syncSelectionToTable() {
        guard let tableView, let selectionGet, let selectionSet else { return }
        let selected = selectionGet()
        let tableSelectedIDs = Set(
            tableView.selectedRowIndexes.compactMap { row -> String? in
                guard row >= 0, row < displayRows.count else { return nil }
                return displayRows[row].id
            }
        )
        if selected.isEmpty, !tableSelectedIDs.isEmpty {
            selectionSet(tableSelectedIDs)
            return
        }
        var indexes = IndexSet()
        for (index, row) in displayRows.enumerated() where selected.contains(row.id) {
            indexes.insert(index)
        }
        if tableView.selectedRowIndexes != indexes {
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
        }
    }

    private func scheduleQuickSearchMatchFocus() {
        DispatchQueue.main.async { [weak self] in
            self?.scrollToFirstQuickSearchMatchIfNeeded()
        }
    }

    override func applyQuickSearchMatchFocus(at row: Int) {
        guard let tableView, row >= 0, row < displayRows.count else { return }
        let matchedRowID = displayRows[row].id
        FileListTableAnimations.performWithoutAnimation {
            scrollQuickSearchMatchRowIntoView(row, in: tableView)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        syncSelectionFromTable()
        interaction.onQuickSearchMatchSelected(matchedRowID)
    }

    private func scrollQuickSearchMatchRowIntoView(_ row: Int, in tableView: NSTableView) {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.length > 0 else {
            tableView.scrollRowToVisible(row)
            return
        }

        let visibleRange = visibleRows.location..<(visibleRows.location + visibleRows.length)
        let filterBarReserve = tableView.rowHeight * 2 + tableView.intercellSpacing.height
        let rowRect = tableView.rect(ofRow: row)
        let visibleRect = tableView.visibleRect

        if visibleRange.contains(row) {
            let hasFilterBarClearance = rowRect.maxY <= visibleRect.maxY - filterBarReserve
            let isNotClippedAtTop = rowRect.minY >= visibleRect.minY
            if hasFilterBarClearance && isNotClippedAtTop {
                return
            }
            if isNotClippedAtTop {
                let anchorRow = min(row + 2, max(0, displayRows.count - 1))
                tableView.scrollRowToVisible(anchorRow)
                return
            }
            tableView.scrollRowToVisible(row)
            return
        }

        if row < visibleRows.location {
            // 命中行在可视区上方（如 Tab 循环回到第一条）：滚到命中行本身，避免 +2 锚点把首行顶出视口。
            tableView.scrollRowToVisible(row)
            return
        }

        let anchorRow = min(row + 2, max(0, displayRows.count - 1))
        tableView.scrollRowToVisible(anchorRow)
    }

    func syncSelectionFromTable() {
        guard let tableView, let selectionGet, let selectionSet else { return }
        let ids = Set(
            tableView.selectedRowIndexes.compactMap { row -> String? in
                guard row >= 0, row < displayRows.count else { return nil }
                return displayRows[row].id
            }
        )
        if selectionGet() != ids {
            selectionSet(ids)
        }
    }
}
