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
    
    var mouseDownRow = -1
    var mouseDownLocation: NSPoint?
    var mouseDownEvent: NSEvent?
    var dragSessionActive = false
    var blankMouseDownEvent: NSEvent?
    var blankIsDragSelecting = false
    var dropHighlightRow: Int?
    let dragThreshold: CGFloat = 4
    
    public var onOpenRow: ((FileListRow) -> Void)?
    
    private var columnResizeObserver: NSObjectProtocol?
    private var columnMoveObserver: NSObjectProtocol?
    private var headerRightClickMonitor: Any?
    private var widthSaveWorkItem: DispatchWorkItem?
    private var isApplyingColumnLayout = false
    private var isUpdatingPaddingColumn = false
    private var pendingPaddingLayout = false
    private var lastColumnStructureToken = ""
    
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
        return scrollView
    }
    
    public func update(
        rows: [FileListRow],
        interaction: FileListTableInteraction,
        selectionGet: @escaping () -> Set<String>,
        selectionSet: @escaping (Set<String>) -> Void,
        preferencesStore: FileListPreferencesStore
    ) {
        sourceRows = rows
        self.interaction = interaction
        self.selectionGet = selectionGet
        self.selectionSet = selectionSet
        self.preferencesStore = preferencesStore
        
        let searchChanged = interaction.searchText != lastSearchText
        lastSearchText = interaction.searchText
        
        let structureToken = columnStructureToken(from: preferencesStore.configuration)
        if structureToken != lastColumnStructureToken {
            lastColumnStructureToken = structureToken
            applyColumnLayout(from: preferencesStore.configuration, full: true)
        }
        
        let sort = preferencesStore.sort
        let newDisplay = FileListSortEngine.sorted(rows, by: sort)
        let displayChanged = newDisplay != displayRows
        displayRows = newDisplay
        
        if displayChanged || searchChanged {
            FileListTableAnimations.performWithoutAnimation {
                tableView?.reloadData()
                updateSortIndicators(for: sort)
            }
        } else {
            updateSortIndicators(for: sort)
        }
        
        schedulePaddingColumnLayout()
        syncSelectionToTable()
    }
    
    func schedulePaddingColumnLayout() {
        guard !pendingPaddingLayout else { return }
        pendingPaddingLayout = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingPaddingLayout = false
            self.updatePaddingColumnWidth()
        }
    }
    
    func dataColumnsTrailingX(in tableView: NSTableView) -> CGFloat {
        var trailing: CGFloat = 0
        for column in tableView.tableColumns {
            guard !FileListPaddingColumn.isPadding(column), !column.isHidden else { continue }
            trailing += column.width
        }
        return trailing
    }
    
    func refreshVisibleRowContentClip() {
        guard let tableView else { return }
        let dataWidth = dataColumnsTrailingX(in: tableView)
        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return }
        for row in visible.location..<(visible.location + visible.length) {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? FileListRowView else {
                continue
            }
            rowView.contentBackgroundMaxX = dataWidth
            rowView.needsDisplay = true
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
        }
        widthSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
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
        guard let tableView, let selectionGet else { return }
        let selected = selectionGet()
        var indexes = IndexSet()
        for (index, row) in displayRows.enumerated() where selected.contains(row.id) {
            indexes.insert(index)
        }
        if tableView.selectedRowIndexes != indexes {
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
        }
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
            self.scheduleWidthSave()
            self.schedulePaddingColumnLayout()
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
    }
    
    private func tearDownObservers() {
        if let columnResizeObserver {
            NotificationCenter.default.removeObserver(columnResizeObserver)
        }
        if let columnMoveObserver {
            NotificationCenter.default.removeObserver(columnMoveObserver)
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
        
        configure(cell: cell, columnID: columnID, item: item)
        return cell
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        syncSelectionFromTable()
        refreshVisibleRowContentClip()
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
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingMiddle
            cell.addSubview(icon)
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 18),
                icon.heightAnchor.constraint(equalToConstant: 18),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            cell.imageView = icon
            cell.textField = label
        default:
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            cell.textField = label
        }
        
        return cell
    }
    
    private func configure(cell: NSTableCellView, columnID: FileListColumnID, item: FileListRow) {
        switch columnID {
        case .name:
            if item.isParentDirectoryEntry {
                cell.imageView?.image = NSImage(systemSymbolName: "arrow.up.circle", accessibilityDescription: nil)
                    ?? NSImage(named: NSImage.folderName)
            } else {
                cell.imageView?.image = NSWorkspace.shared.icon(forFile: item.iconPath)
            }
            cell.textField?.attributedStringValue = FileListTextHighlight.attributedName(
                item.name,
                searchText: interaction.searchText,
                isDirectory: item.isDirectory || item.isParentDirectoryEntry,
                isHidden: item.isHidden
            )
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
