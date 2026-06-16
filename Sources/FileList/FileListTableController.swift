import AppKit
import Foundation

/// NSTableView 数据源、列配置、排序与表头交互的统一控制器。
public final class FileListTableController: NSObject {
    public static weak var shared: FileListTableController?
    
    private(set) var scrollView: NSScrollView?
    private(set) var tableView: NSTableView?
    
    private var sourceRows: [FileListRow] = []
    private(set) var displayRows: [FileListRow] = []
    var selectionGet: (() -> Set<String>)?
    var selectionSet: ((Set<String>) -> Void)?
    private weak var preferencesStore: FileListPreferencesStore?
    var interaction = FileListTableInteraction()
    var lastSearchText = ""
    var lastQuickSearchText = ""
    
    var mouseDownRow = -1
    var mouseDownLocation: NSPoint?
    var mouseDownEvent: NSEvent?
    var mouseDownCanStartFileDrag = false
    var dragSessionActive = false
    var blankMouseDownEvent: NSEvent?
    var blankDragSelecting = false
    var dropHighlightRow: Int?
    let dragThreshold: CGFloat = 4
    
    public var onOpenRow: ((FileListRow) -> Void)?
    public var onVisibleDirectoryPathsChanged: (([String]) -> Void)?
    
    private var columnResizeObserver: NSObjectProtocol?
    private var columnMoveObserver: NSObjectProtocol?
    private var scrollBoundsObserver: NSObjectProtocol?
    private var headerRightClickMonitor: Any?
    private var widthSaveWorkItem: DispatchWorkItem?
    private var paddingAfterResizeWorkItem: DispatchWorkItem?
    private var visiblePathsNotifyWorkItem: DispatchWorkItem?
    private var lastReportedVisibleDirectoryPaths: [String] = []
    private var isApplyingColumnLayout = false
    private var isUpdatingPaddingColumn = false
    private var pendingPaddingLayout = false
    private var lastColumnStructureToken = ""
    private var lastFillLayoutRowCount = -1
    private var lastFillLayoutClipHeight: CGFloat = -1
    private var lastFillLayoutClipWidth: CGFloat = -1
    private var lastListingSignature = ""
    private var pendingScrollToTop = false
    private var lastDirectorySizeRevision: UInt = 0
    private var pendingDirectorySizeRefresh = false
    private var directorySizeDisplay: ((String) -> DirectorySizeDisplayInfo)?
    
    private let userResizing = NSTableColumn.ResizingOptions(rawValue: 1 << 1)
    
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
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        tableView.setDraggingSourceOperationMask([.move, .copy], forLocal: false)
        
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
        self.interaction = interaction
        self.selectionGet = selectionGet
        self.selectionSet = selectionSet
        self.preferencesStore = preferencesStore
        
        let searchChanged = interaction.searchText != lastSearchText
        lastSearchText = interaction.searchText
        let quickSearchChanged = interaction.quickSearchText != lastQuickSearchText
        lastQuickSearchText = interaction.quickSearchText
        
        let structureToken = columnStructureToken(from: preferencesStore.configuration)
        if structureToken != lastColumnStructureToken {
            lastColumnStructureToken = structureToken
            applyColumnLayout(from: preferencesStore.configuration, full: true)
        }
        
        let listingSignature = rows.map(\.id).joined(separator: "\u{1F}")
        let listingChanged = listingSignature != lastListingSignature
        if listingChanged {
            lastListingSignature = listingSignature
            lastDirectorySizeRevision = 0
        }
        
        let previousSourceRows = sourceRows
        let mergedRows: [FileListRow]
        if listingChanged || previousSourceRows.isEmpty {
            mergedRows = rows
        } else {
            mergedRows = mergePreservingDirectorySizes(incoming: rows, existing: previousSourceRows)
        }
        sourceRows = mergedRows
        
        let sort = preferencesStore.sort
        let previousDisplayRows = displayRows
        let newDisplay = FileListSortEngine.sorted(mergedRows, by: sort)
        let newOrder = newDisplay.map(\.id)
        let oldOrder = previousDisplayRows.map(\.id)
        let orderChanged = newOrder != oldOrder
        
        let sizeOnlyChanged = !orderChanged
            && !searchChanged
            && !listingChanged
            && newDisplay.count == previousDisplayRows.count
            && zip(newDisplay, previousDisplayRows).allSatisfy { $0.hasSameStaticContent(as: $1) }
            && zip(newDisplay, previousDisplayRows).contains { $0.size != $1.size || $0.sizeDisplay != $1.sizeDisplay }
        
        displayRows = newDisplay
        if orderChanged {
            lastReportedVisibleDirectoryPaths = []
        }
        
        if orderChanged || searchChanged {
            lastFillLayoutRowCount = -1
            FileListTableAnimations.performWithoutAnimation {
                if orderChanged && !searchChanged && !listingChanged {
                    reloadDataPreservingVisibleRowAnchor(previousRows: previousDisplayRows)
                } else {
                    tableView?.reloadData()
                }
                updateSortIndicators(for: sort)
                if listingChanged {
                    pendingScrollToTop = true
                    scrollToTop()
                }
            }
        } else if sizeOnlyChanged {
            reloadSizeColumnPreservingScroll()
        } else if !orderChanged && !searchChanged && !quickSearchChanged && !listingChanged && newDisplay == previousDisplayRows {
            scheduleVisibleDirectoryPathsNotify()
            return
        }
        updateSortIndicators(for: sort)
        
        schedulePaddingColumnLayout()
        if orderChanged || searchChanged || listingChanged {
            syncSelectionToTable()
        }
        if quickSearchChanged {
            refreshVisibleNameLabels()
            scrollToFirstQuickSearchMatchIfNeeded()
        }
        scheduleVisibleDirectoryPathsNotify()
    }
    
    /// SwiftUI 传入的行不含异步回填的目录大小；选中变化触发的 update 须保留已有 Size 列数据。
    private func mergePreservingDirectorySizes(incoming: [FileListRow], existing: [FileListRow]) -> [FileListRow] {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        return incoming.map { row in
            guard row.isDirectory, !row.isParentDirectoryEntry else { return row }
            
            if let directorySizeDisplay {
                let info = directorySizeDisplay(row.iconPath)
                if info != .unknown {
                    return row.withDirectorySizeDisplay(info)
                }
            }
            
            guard let cached = existingByID[row.id], cached.sizeDisplay != "--" else {
                return row
            }
            return row.withDirectorySizeDisplay(
                DirectorySizeDisplayInfo(sortableSize: cached.size, text: cached.sizeDisplay)
            )
        }
    }
    
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
    
    private var isUserPointerActive: Bool {
        mouseDownEvent != nil || blankMouseDownEvent != nil || dragSessionActive
    }
    
    func finishPointerInteractionIfNeeded() {
        mouseDownEvent = nil
        mouseDownRow = -1
        mouseDownLocation = nil
        mouseDownCanStartFileDrag = false
        blankDragSelecting = false
        flushPendingDirectorySizeRefreshIfNeeded()
    }
    
    private func flushPendingDirectorySizeRefreshIfNeeded() {
        guard pendingDirectorySizeRefresh else { return }
        applyDirectorySizeDisplayUpdates()
    }
    
    private func applyDirectorySizeDisplayUpdates() {
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
    
    private func sizeColumnIndex(in tableView: NSTableView) -> Int? {
        tableView.tableColumns.firstIndex { FileListColumnID.from(column: $0) == .size }
    }
    
    private func scrollToTop() {
        guard let tableView, let scrollView, !displayRows.isEmpty else { return }
        FileListTableAnimations.performWithoutAnimation {
            tableView.scrollRowToVisible(0)
            let clipView = scrollView.contentView
            if clipView.bounds.origin.y > 0.5 {
                clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: 0))
                scrollView.reflectScrolledClipView(clipView)
            }
        }
    }
    
    private func reloadSizeColumnPreservingScroll() {
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
    
    private func reloadDataPreservingVisibleRowAnchor(previousRows: [FileListRow]) {
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
    
    func scheduleVisibleDirectoryPathsNotify() {
        visiblePathsNotifyWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reportVisibleDirectoryPathsIfNeeded()
        }
        visiblePathsNotifyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
    
    private func reportVisibleDirectoryPathsIfNeeded() {
        guard let tableView, let onVisibleDirectoryPathsChanged else { return }
        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return }
        
        var paths: [String] = []
        paths.reserveCapacity(visible.length)
        for row in visible.location..<(visible.location + visible.length) {
            let item = displayRows[row]
            guard item.isDirectory, !item.isParentDirectoryEntry else { continue }
            paths.append(item.iconPath)
        }
        
        guard paths != lastReportedVisibleDirectoryPaths else { return }
        lastReportedVisibleDirectoryPaths = paths
        onVisibleDirectoryPathsChanged(paths)
    }
    
    func schedulePaddingColumnLayout() {
        guard !pendingPaddingLayout else { return }
        pendingPaddingLayout = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingPaddingLayout = false
            self.ensureTableViewFillsClipViewIfNeeded()
            self.updatePaddingColumnWidth()
            if self.pendingScrollToTop {
                self.pendingScrollToTop = false
                self.scrollToTop()
            }
        }
    }
    
    func dataColumnsTrailingX(in tableView: NSTableView) -> CGFloat {
        var lastDataColumnIndex: Int?
        for (index, column) in tableView.tableColumns.enumerated() {
            guard !FileListPaddingColumn.isPadding(column), !column.isHidden else { continue }
            lastDataColumnIndex = index
        }
        guard let lastDataColumnIndex else { return 0 }
        tableView.layoutSubtreeIfNeeded()
        return tableView.rect(ofColumn: lastDataColumnIndex).maxX
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
    
    func refreshVisibleNameLabels() {
        guard let tableView else { return }
        guard let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
            FileListColumnID.from(column: $0) == .name
        }) else { return }
        
        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return }
        let isEmphasized = tableView.window?.isKeyWindow ?? true
        
        for row in visible.location..<(visible.location + visible.length) {
            guard row >= 0, row < displayRows.count,
                  let cell = tableView.view(atColumn: nameColumnIndex, row: row, makeIfNecessary: false) as? NSTableCellView
            else { continue }
            applyNameLabel(
                in: cell,
                item: displayRows[row],
                isSelected: tableView.selectedRowIndexes.contains(row),
                isEmphasized: isEmphasized
            )
        }
    }
    
    func updatePaddingColumnWidth() {
        guard let tableView, let padding = FileListPaddingColumn.column(in: tableView) else { return }
        guard !isUpdatingPaddingColumn else { return }
        guard tableView.bounds.width > 1 else { return }
        
        isUpdatingPaddingColumn = true
        defer { isUpdatingPaddingColumn = false }
        
        ensurePaddingColumnLast()
        let dataWidth = dataColumnsTrailingX(in: tableView)
        let trailingWidth = max(0, tableView.bounds.width - dataWidth)
        if abs(padding.width - trailingWidth) > 0.5 {
            padding.width = trailingWidth
        }
        contentBackgroundMaxX = dataWidth
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return }
        for row in 0..<rowCount {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? FileListRowView else {
                continue
            }
            rowView.contentBackgroundMaxX = dataWidth
            rowView.needsDisplay = true
        }
    }
    
    func ensurePaddingColumnLast() {
        guard let tableView, let padding = FileListPaddingColumn.column(in: tableView),
              let lastIndex = tableView.tableColumns.indices.last,
              tableView.tableColumns[lastIndex] !== padding,
              let currentIndex = tableView.tableColumns.firstIndex(of: padding) else { return }
        tableView.moveColumn(currentIndex, toColumn: lastIndex)
    }
    
    func isBlankPaddingPoint(_ point: NSPoint, in tableView: NSTableView) -> Bool {
        let columnIndex = tableView.column(at: point)
        guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return false }
        return FileListPaddingColumn.isPadding(tableView.tableColumns[columnIndex])
    }
    
    /// 最后一行下方的空白区（行数较少时列表底部留白）。
    func isBelowRowsBlankPoint(_ point: NSPoint, in tableView: NSTableView) -> Bool {
        guard tableView.bounds.contains(point) else { return false }
        
        if let headerView = tableView.headerView, headerView.frame.contains(point) {
            return false
        }
        
        // 用系统行命中检测，避免手写 Y 坐标在翻转/拉伸后误判整表为空白。
        return tableView.row(at: point) < 0
    }
    
    /// 右侧 padding 列或行下方的空白区。
    func isBlankInteractivePoint(_ point: NSPoint, in tableView: NSTableView) -> Bool {
        isBlankPaddingPoint(point, in: tableView) || isBelowRowsBlankPoint(point, in: tableView)
    }
    
    /// 让表格至少铺满滚动区域，使底部留白能接收点击。
    func ensureTableViewFillsClipViewIfNeeded() {
        guard let scrollView, let tableView else { return }
        let clipSize = scrollView.contentView.bounds.size
        let rowCount = tableView.numberOfRows
        guard rowCount != lastFillLayoutRowCount
                || abs(clipSize.height - lastFillLayoutClipHeight) > 0.5
                || abs(clipSize.width - lastFillLayoutClipWidth) > 0.5
        else { return }
        
        lastFillLayoutRowCount = rowCount
        lastFillLayoutClipHeight = clipSize.height
        lastFillLayoutClipWidth = clipSize.width
        ensureTableViewFillsClipView()
    }
    
    /// 让表格至少铺满滚动区域，使底部留白能接收点击。
    func ensureTableViewFillsClipView() {
        guard let scrollView, let tableView else { return }
        let clipView = scrollView.contentView
        let clipSize = clipView.bounds.size
        guard clipSize.width > 1, clipSize.height > 1 else { return }
        
        let contentHeight = measuredTableContentHeight()
        let targetHeight = max(contentHeight, clipSize.height)
        var frame = tableView.frame
        var changed = false
        
        let heightDelta = targetHeight - frame.size.height
        if abs(heightDelta) > 0.5 {
            frame.size.height = targetHeight
            frame.origin.y -= heightDelta
            changed = true
        }
        if abs(frame.size.width - clipSize.width) > 0.5 {
            frame.size.width = clipSize.width
            changed = true
        }
        if changed {
            let savedBoundsOrigin = clipView.bounds.origin
            tableView.frame = frame
            clipView.bounds.origin = savedBoundsOrigin
        }
    }
    
    private func measuredTableContentHeight() -> CGFloat {
        guard let tableView else { return 0 }
        tableView.layoutSubtreeIfNeeded()
        
        let headerHeight = tableView.headerView?.frame.height ?? 0
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return headerHeight }
        
        let firstRowRect = tableView.rect(ofRow: 0)
        let lastRowRect = tableView.rect(ofRow: rowCount - 1)
        let rowsSpan = abs(firstRowRect.maxY - lastRowRect.minY)
        return headerHeight + rowsSpan
    }
    
    private var contentBackgroundMaxX: CGFloat = 0
    
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
    
    private func updateSortIndicators(for sort: FileListSortState) {
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
    
    @objc private func handleDoubleClick(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < displayRows.count else { return }
        onOpenRow?(displayRows[row])
    }
    
    // MARK: - Column layout
    
    private func columnStructureToken(from configuration: FileListColumnConfiguration) -> String {
        let order = configuration.order.map(\.rawValue).joined(separator: ",")
        let visible = configuration.visible.map(\.rawValue).sorted().joined(separator: ",")
        return "\(order)|\(visible)"
    }
    
    private func applyColumnLayout(from configuration: FileListColumnConfiguration, full: Bool) {
        guard let tableView, !isApplyingColumnLayout else { return }
        isApplyingColumnLayout = true
        defer { isApplyingColumnLayout = false }
        
        FileListTableAnimations.performWithoutAnimation {
            var config = configuration
            config.visible.insert(.name)
            
            for column in tableView.tableColumns {
                guard let columnID = FileListColumnID.from(column: column) else { continue }
                let shouldShow = columnID == .name || config.visible.contains(columnID)
                column.isHidden = !shouldShow
                guard shouldShow else { continue }
                applyStoredWidth(to: column, columnID: columnID, configuration: config)
            }
            
            if full {
                for (targetIndex, columnID) in config.order.enumerated() {
                    guard let column = tableColumn(for: columnID, in: tableView),
                          let currentIndex = tableView.tableColumns.firstIndex(of: column),
                          currentIndex != targetIndex else { continue }
                    tableView.moveColumn(currentIndex, toColumn: targetIndex)
                }
            }
            ensurePaddingColumnLast()
            schedulePaddingColumnLayout()
        }
    }
    
    private func applyStoredWidth(
        to column: NSTableColumn,
        columnID: FileListColumnID,
        configuration: FileListColumnConfiguration
    ) {
        column.minWidth = columnID.minWidth
        column.maxWidth = columnID.maxWidth
        column.resizingMask = userResizing
        
        if let stored = configuration.width(for: columnID) {
            column.width = min(max(stored, columnID.minWidth), columnID.maxWidth)
        } else if column.width < columnID.minWidth || column.width > columnID.maxWidth {
            column.width = columnID.idealWidth
        }
    }
    
    private func tableColumn(for columnID: FileListColumnID, in tableView: NSTableView) -> NSTableColumn? {
        tableView.tableColumns.first {
            FileListColumnID.from(column: $0) == columnID
        }
    }
    
    private func captureColumnWidths() {
        guard let tableView, let preferencesStore else { return }
        var configuration = preferencesStore.configuration
        for column in tableView.tableColumns {
            guard let columnID = FileListColumnID.from(column: column),
                  !column.isHidden else { continue }
            configuration.setWidth(column.width, for: columnID)
        }
        preferencesStore.updateColumns(configuration)
    }
    
    private func scheduleWidthSave() {
        widthSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.captureColumnWidths()
            self?.updatePaddingColumnWidth()
        }
        widthSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    
    /// 列宽拖拽过程中不立即改 padding 列，避免打断系统调宽。
    func schedulePaddingColumnWidthAfterResize() {
        paddingAfterResizeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.updatePaddingColumnWidth()
        }
        paddingAfterResizeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
    
    private func syncOrderFromTableView() {
        guard let tableView, let preferencesStore, !isApplyingColumnLayout else { return }
        
        var newOrder: [FileListColumnID] = []
        for column in tableView.tableColumns {
            guard let columnID = FileListColumnID.from(column: column),
                  !newOrder.contains(columnID) else { continue }
            newOrder.append(columnID)
        }
        for columnID in FileListColumnID.allCases where !newOrder.contains(columnID) {
            newOrder.append(columnID)
        }
        
        var configuration = preferencesStore.configuration
        guard configuration.order != newOrder else { return }
        
        captureColumnWidths()
        configuration = preferencesStore.configuration
        configuration.order = newOrder
        preferencesStore.updateColumns(configuration)
        lastColumnStructureToken = columnStructureToken(from: configuration)
    }
    
    // MARK: - Header menu
    
    private func presentHeaderMenu(for event: NSEvent, clickedColumnID: FileListColumnID?) {
        guard let tableView, let headerView = tableView.headerView,
              let preferencesStore else { return }
        
        let menu = NSMenu()
        let configuration = preferencesStore.configuration
        let menuColumns = configuration.order.filter(\.isMenuToggleable)
        
        for columnID in menuColumns {
            let item = NSMenuItem(
                title: columnID.menuTitle,
                action: #selector(toggleColumnVisibility(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = columnID.rawValue
            item.state = configuration.visible.contains(columnID) ? .on : .off
            menu.addItem(item)
        }
        
        if let clickedColumnID, clickedColumnID.isMenuToggleable {
            menu.addItem(.separator())
            
            let moveLeft = NSMenuItem(title: "左移", action: #selector(moveColumnLeft(_:)), keyEquivalent: "")
            moveLeft.target = self
            moveLeft.representedObject = clickedColumnID.rawValue
            moveLeft.isEnabled = configuration.canMoveColumn(clickedColumnID, offset: -1)
            menu.addItem(moveLeft)
            
            let moveRight = NSMenuItem(title: "右移", action: #selector(moveColumnRight(_:)), keyEquivalent: "")
            moveRight.target = self
            moveRight.representedObject = clickedColumnID.rawValue
            moveRight.isEnabled = configuration.canMoveColumn(clickedColumnID, offset: 1)
            menu.addItem(moveRight)
        }
        
        NSMenu.popUpContextMenu(menu, with: event, for: headerView)
    }
    
    @objc private func toggleColumnVisibility(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let columnID = FileListColumnID(rawValue: rawValue),
              let preferencesStore else { return }
        captureColumnWidths()
        var configuration = preferencesStore.configuration
        guard configuration.toggleVisibility(columnID) else { return }
        preferencesStore.updateColumns(configuration)
        lastColumnStructureToken = columnStructureToken(from: configuration)
        applyColumnLayout(from: configuration, full: true)
        tableView?.reloadData()
    }
    
    @objc private func moveColumnLeft(_ sender: NSMenuItem) {
        moveColumn(sender, offset: -1)
    }
    
    @objc private func moveColumnRight(_ sender: NSMenuItem) {
        moveColumn(sender, offset: 1)
    }
    
    private func moveColumn(_ sender: NSMenuItem, offset: Int) {
        guard let rawValue = sender.representedObject as? String,
              let columnID = FileListColumnID(rawValue: rawValue),
              let preferencesStore else { return }
        captureColumnWidths()
        var configuration = preferencesStore.configuration
        guard configuration.moveColumn(columnID, offset: offset) else { return }
        preferencesStore.updateColumns(configuration)
        lastColumnStructureToken = columnStructureToken(from: configuration)
        applyColumnLayout(from: configuration, full: true)
    }
    
    // MARK: - Selection
    
    private func syncSelectionToTable() {
        guard let tableView, let selectionGet, let selectionSet else { return }
        let selected = selectionGet()
        let tableSelectedIDs = Set(
            tableView.selectedRowIndexes.compactMap { row -> String? in
                guard row >= 0, row < displayRows.count else { return nil }
                return displayRows[row].id
            }
        )
        // 用户点击后 binding 可能尚未刷新；此时不要用空 binding 覆盖表格选中。
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

    private func scrollToFirstQuickSearchMatchIfNeeded() {
        guard let tableView else { return }
        let keyword = interaction.quickSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        guard let row = displayRows.firstIndex(where: {
            !$0.isParentDirectoryEntry &&
            $0.name.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: .current
            ) != nil
        }) else { return }
        
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
    
    // MARK: - Observers
    
    private func installObservers() {
        guard let tableView else { return }
        
        columnResizeObserver = NotificationCenter.default.addObserver(
            forName: NSTableView.columnDidResizeNotification,
            object: tableView,
            queue: .main
        ) { [weak self] notification in
            guard let self, !self.isUpdatingPaddingColumn else { return }
            if let column = notification.userInfo?["NSTableColumn"] as? NSTableColumn,
               FileListPaddingColumn.isPadding(column) {
                return
            }
            self.refreshVisibleRowContentClip()
            self.scheduleWidthSave()
            self.schedulePaddingColumnWidthAfterResize()
        }
        
        columnMoveObserver = NotificationCenter.default.addObserver(
            forName: NSTableView.columnDidMoveNotification,
            object: tableView,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.isUpdatingPaddingColumn else { return }
            self.syncOrderFromTableView()
            self.schedulePaddingColumnLayout()
        }
        
        headerRightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) {
            [weak self] event in
            guard let self, let tableView = self.tableView,
                  let headerView = tableView.headerView,
                  event.window === headerView.window else { return event }
            let pointInHeader = headerView.convert(event.locationInWindow, from: nil)
            guard headerView.bounds.contains(pointInHeader) else { return event }
            let columnID = self.columnID(at: pointInHeader, in: tableView)
            self.presentHeaderMenu(for: event, clickedColumnID: columnID)
            return nil
        }
        
        if let scrollView {
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollBoundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleVisibleDirectoryPathsNotify()
            }
        }
    }
    
    private func tearDownObservers() {
        if let columnResizeObserver {
            NotificationCenter.default.removeObserver(columnResizeObserver)
        }
        if let columnMoveObserver {
            NotificationCenter.default.removeObserver(columnMoveObserver)
        }
        if let scrollBoundsObserver {
            NotificationCenter.default.removeObserver(scrollBoundsObserver)
        }
        if let headerRightClickMonitor {
            NSEvent.removeMonitor(headerRightClickMonitor)
        }
    }
    
    private func columnID(at pointInHeader: NSPoint, in tableView: NSTableView) -> FileListColumnID? {
        guard let headerView = tableView.headerView else { return nil }
        let pointInTable = tableView.convert(pointInHeader, from: headerView)
        let columnIndex = tableView.column(at: pointInTable)
        guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return nil }
        return FileListColumnID.from(column: tableView.tableColumns[columnIndex])
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension FileListTableController: NSTableViewDataSource, NSTableViewDelegate {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        displayRows.count
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, row >= 0, row < displayRows.count else { return nil }
        
        if FileListPaddingColumn.isPadding(tableColumn) {
            let identifier = NSUserInterfaceItemIdentifier("FileListCell.padding")
            if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
                return reused
            }
            let cell = NSTableCellView()
            cell.identifier = identifier
            return cell
        }
        
        guard let columnID = FileListColumnID.from(column: tableColumn) else { return nil }
        
        let item = displayRows[row]
        let identifier = NSUserInterfaceItemIdentifier("FileListCell.\(columnID.rawValue)")
        
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeCell(for: columnID, identifier: identifier)
        }
        
        configure(cell: cell, columnID: columnID, item: item, row: row)
        return cell
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        syncSelectionFromTable()
        refreshVisibleRowContentClip()
        refreshVisibleNameLabels()
    }
    
    public func tableView(
        _ tableView: NSTableView,
        shouldReorderColumn columnIndex: Int,
        toColumn newColumnIndex: Int
    ) -> Bool {
        guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return false }
        guard newColumnIndex >= 0, newColumnIndex < tableView.tableColumns.count else { return false }
        let moving = tableView.tableColumns[columnIndex]
        let target = tableView.tableColumns[newColumnIndex]
        return !FileListPaddingColumn.isPadding(moving) && !FileListPaddingColumn.isPadding(target)
    }
    
    private func makeCell(for columnID: FileListColumnID, identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        
        switch columnID {
        case .name:
            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.imageScaling = .scaleProportionallyDown
            let label = FileListTruncatingLabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(icon)
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 18),
                icon.heightAnchor.constraint(equalToConstant: 18),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.topAnchor.constraint(equalTo: cell.topAnchor),
                label.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
            ])
            cell.imageView = icon
        default:
            let label = makeTruncatingLabel(truncation: .byTruncatingTail)
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            cell.textField = label
        }
        
        return cell
    }
    
    private func makeTruncatingLabel(truncation: NSLineBreakMode) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        applyTruncationSettings(to: label, truncation: truncation)
        return label
    }
    
    private func applyTruncationSettings(to label: NSTextField, truncation: NSLineBreakMode) {
        label.lineBreakMode = truncation
        label.usesSingleLineMode = true
        if let cell = label.cell as? NSTextFieldCell {
            cell.lineBreakMode = truncation
            cell.truncatesLastVisibleLine = true
            cell.wraps = false
            cell.isScrollable = false
        }
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    
    private func nameLabel(in cell: NSTableCellView) -> FileListTruncatingLabel? {
        cell.subviews.compactMap { $0 as? FileListTruncatingLabel }.first
    }
    
    func isFileNameTextPoint(_ point: NSPoint, row: Int, in tableView: NSTableView) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        let column = tableView.column(at: point)
        guard column >= 0, column < tableView.tableColumns.count else { return false }
        guard FileListColumnID.from(column: tableView.tableColumns[column]) == .name else { return false }
        guard let nameCell = tableView.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
              let label = nameLabel(in: nameCell) else {
            return false
        }
        
        let pointInCell = nameCell.convert(point, from: tableView)
        let pointInLabel = label.convert(pointInCell, from: nameCell)
        guard label.bounds.contains(pointInLabel) else { return false }
        
        // 仅文字本体区域触发文件拖拽；名称列右侧空白应交给框选逻辑。
        let textRect = label.visibleTextRect()
        return textRect.contains(pointInLabel)
    }
    
    private func applyNameLabel(
        in cell: NSTableCellView,
        item: FileListRow,
        isSelected: Bool,
        isEmphasized: Bool
    ) {
        let highlightText = interaction.quickSearchText.isEmpty
            ? interaction.searchText
            : interaction.quickSearchText
        nameLabel(in: cell)?.attributedString = FileListTextHighlight.attributedName(
            item.name,
            searchText: highlightText,
            isDirectory: item.isDirectory || item.isParentDirectoryEntry,
            isHidden: item.isHidden,
            isSelected: isSelected,
            isEmphasized: isEmphasized
        )
    }
    
    private func configure(cell: NSTableCellView, columnID: FileListColumnID, item: FileListRow, row: Int) {
        if let label = cell.textField {
            applyTruncationSettings(to: label, truncation: .byTruncatingTail)
        }
        
        switch columnID {
        case .name:
            if item.isParentDirectoryEntry {
                cell.imageView?.image = NSImage(systemSymbolName: "arrow.up.circle", accessibilityDescription: nil)
                    ?? NSImage(named: NSImage.folderName)
            } else {
                cell.imageView?.image = NSWorkspace.shared.icon(forFile: item.iconPath)
            }
            let isSelected = tableView?.selectedRowIndexes.contains(row) ?? false
            let isEmphasized = tableView?.window?.isKeyWindow ?? true
            applyNameLabel(in: cell, item: item, isSelected: isSelected, isEmphasized: isEmphasized)
        case .type:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.fileType
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .secondaryLabelColor
        case .size:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.sizeDisplay
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .secondaryLabelColor
        case .dateModified:
            cell.textField?.stringValue = item.isParentDirectoryEntry ? "" : item.dateDisplay
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            cell.textField?.textColor = .labelColor
        }
    }
}
