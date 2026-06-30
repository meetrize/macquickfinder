import AppKit
import Foundation

// MARK: - Padding & fill layout

extension FileListTableController {
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

        return tableView.row(at: point) < 0
    }

    /// 右侧 padding 列或行下方的空白区。
    func isBlankInteractivePoint(_ point: NSPoint, in tableView: NSTableView) -> Bool {
        isBlankPaddingPoint(point, in: tableView) || isBelowRowsBlankPoint(point, in: tableView)
    }

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
            frame.origin.y = 0
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

    func measuredTableContentHeight() -> CGFloat {
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

    func scrollToTop() {
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
}

// MARK: - Column structure

extension FileListTableController {
    func columnStructureToken(from configuration: FileListColumnConfiguration) -> String {
        let order = configuration.order.map(\.rawValue).joined(separator: ",")
        let visible = configuration.visible.map(\.rawValue).sorted().joined(separator: ",")
        return "\(order)|\(visible)"
    }

    func applyColumnLayout(from configuration: FileListColumnConfiguration, full: Bool) {
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

    func applyStoredWidth(
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

    func tableColumn(for columnID: FileListColumnID, in tableView: NSTableView) -> NSTableColumn? {
        tableView.tableColumns.first {
            FileListColumnID.from(column: $0) == columnID
        }
    }

    func captureColumnWidths() {
        guard let tableView, let preferencesStore else { return }
        var configuration = preferencesStore.configuration
        for column in tableView.tableColumns {
            guard let columnID = FileListColumnID.from(column: column),
                  !column.isHidden else { continue }
            configuration.setWidth(column.width, for: columnID)
        }
        preferencesStore.updateColumns(configuration)
    }

    func scheduleWidthSave() {
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

    func syncOrderFromTableView() {
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
}

// MARK: - Header menu

extension FileListTableController {
    func presentHeaderMenu(for event: NSEvent, clickedColumnID: FileListColumnID?) {
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

            let moveLeft = NSMenuItem(title: L10n.Column.moveLeft, action: #selector(moveColumnLeft(_:)), keyEquivalent: "")
            moveLeft.target = self
            moveLeft.representedObject = clickedColumnID.rawValue
            moveLeft.isEnabled = configuration.canMoveColumn(clickedColumnID, offset: -1)
            menu.addItem(moveLeft)

            let moveRight = NSMenuItem(title: L10n.Column.moveRight, action: #selector(moveColumnRight(_:)), keyEquivalent: "")
            moveRight.target = self
            moveRight.representedObject = clickedColumnID.rawValue
            moveRight.isEnabled = configuration.canMoveColumn(clickedColumnID, offset: 1)
            menu.addItem(moveRight)
        }

        NSMenu.popUpContextMenu(menu, with: event, for: headerView)
    }

    @objc func toggleColumnVisibility(_ sender: NSMenuItem) {
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

    @objc func moveColumnLeft(_ sender: NSMenuItem) {
        moveColumn(sender, offset: -1)
    }

    @objc func moveColumnRight(_ sender: NSMenuItem) {
        moveColumn(sender, offset: 1)
    }

    func moveColumn(_ sender: NSMenuItem, offset: Int) {
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
}

// MARK: - Observers

extension FileListTableController {
    func installObservers() {
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
                self?.scheduleVisibleDirectoryPathsNotify(debounce: 0.15)
                self?.scheduleVisibleIconPreviewLoad()
                self?.refreshRowHoverHighlightFromCurrentMouseLocation()
            }
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

    func tearDownObservers() {
        if let memoryPressureObserver {
            NotificationCenter.default.removeObserver(memoryPressureObserver)
            self.memoryPressureObserver = nil
        }
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

    func columnID(at pointInHeader: NSPoint, in tableView: NSTableView) -> FileListColumnID? {
        guard let headerView = tableView.headerView else { return nil }
        let pointInTable = tableView.convert(pointInHeader, from: headerView)
        let columnIndex = tableView.column(at: pointInTable)
        guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else { return nil }
        return FileListColumnID.from(column: tableView.tableColumns[columnIndex])
    }
}
