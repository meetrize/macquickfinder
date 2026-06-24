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
    var pendingRenameRow = -1

    var columnResizeObserver: NSObjectProtocol?
    var columnMoveObserver: NSObjectProtocol?
    var scrollBoundsObserver: NSObjectProtocol?
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

        installObservers()
        ensureTableViewFillsClipViewIfNeeded()
        return scrollView
    }

    public func update(
        rows: [FileListRow],
        interaction: FileListTableInteraction,
        selectionGet: @escaping () -> Set<String>,
        selectionSet: @escaping (Set<String>) -> Void,
        preferencesStore: FileListPreferencesStore
    ) {
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
        if plan.listingChanged, renamingRowID != nil {
            cancelRenameIfNeededForDataUpdate()
        }

        let newDisplay = plan.sortedDisplayRows
        let sizeOnlyChanged = !plan.orderChanged
            && !plan.searchChanged
            && !plan.listingChanged
            && newDisplay.count == previousDisplayRows.count
            && zip(newDisplay, previousDisplayRows).allSatisfy { $0.hasSameStaticContent(as: $1) }
            && zip(newDisplay, previousDisplayRows).contains { $0.size != $1.size || $0.sizeDisplay != $1.sizeDisplay }

        if plan.displayUnchanged {
            scheduleVisibleDirectoryPathsNotify(debounce: 0.15)
            return
        }

        let sort = preferencesStore.sort
        if plan.orderChanged || plan.searchChanged {
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
            scrollToFirstQuickSearchMatchIfNeeded()
        }
        scheduleVisibleDirectoryPathsNotify(debounce: 0.15)
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
            if columnID == sort.column {
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

    func scrollToFirstQuickSearchMatchIfNeeded() {
        guard let tableView, let row = firstQuickSearchMatchIndex() else { return }
        FileListTableAnimations.performWithoutAnimation {
            tableView.scrollRowToVisible(row)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        syncSelectionFromTable()
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
