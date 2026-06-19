import SwiftUI
import AppKit
import UniformTypeIdentifiers
import FileList

// MARK: - Pasteboard

enum FavoriteSidebarPasteboard {
    static let reorderType = NSPasteboard.PasteboardType("com.explorer.favorite-row")
    
    static let draggedTypes: [NSPasteboard.PasteboardType] = [
        reorderType,
        .fileURL,
        NSPasteboard.PasteboardType(UTType.fileURL.identifier),
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),
    ]
}

enum FavoriteSidebarRailLayout {
    /// 与 `LeftPanelLayoutConstants.railWidth`（54）减去左右 padding（8）对齐。
    static let contentWidth: CGFloat = 46
}

private enum FavoriteSidebarMetrics {
    static let railContentWidth = FavoriteSidebarRailLayout.contentWidth
    static let sidebarColumnWidth: CGFloat = 240
    /// 与 `SidebarRow`（body + vertical 4）视觉行高对齐。
    static let sidebarRowHeight: CGFloat = 24
    static let railRowHeight: CGFloat = 28
    static let rowContentInset: CGFloat = 8
    /// 与 `SidebarRailView` 水平 padding 一致（用于拖放指示线等）。
    static let railSelectionHorizontalInset: CGFloat = 4
    /// 侧栏模式下图标左边距（比 `SidebarRow` 视觉基准左移 3pt 以与 Devices 对齐）。
    static let sidebarIconLeadingInset: CGFloat = 3
}

// MARK: - Controller

@MainActor
final class FavoritesSidebarController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSDraggingSource {
    var parent: FavoritesSidebarHost
    weak var tableView: FavoritesTableView?
    
    private var lastItemPaths: [String] = []
    private var lastShowsTitle = true
    private var pendingDropRow = -1
    private var pendingInsertBeforeIndex = -1
    private var reorderDragRow = -1
    
    init(parent: FavoritesSidebarHost) {
        self.parent = parent
    }
    
    func bootstrap(showsTitle: Bool) {
        lastShowsTitle = showsTitle
        lastItemPaths = parent.favoritesStore.items.map(\.path)
    }
    
    func syncFromParent() {
        let paths = parent.favoritesStore.items.map(\.path)
        let showsTitle = parent.showsTitle
        let layoutChanged = showsTitle != lastShowsTitle
        if paths != lastItemPaths || layoutChanged {
            lastItemPaths = paths
            lastShowsTitle = showsTitle
            if layoutChanged {
                tableView?.applyShowsTitleLayout(showsTitle)
            }
            tableView?.reloadData()
            tableView?.invalidateIntrinsicContentSize()
            if layoutChanged {
                scheduleLayoutRefreshAfterModeChange()
            }
        }
        refreshRowHighlighting()
    }
    
    func scheduleLayoutRefreshAfterModeChange() {
        guard tableView != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let tableView = self.tableView else { return }
            tableView.layoutSubtreeIfNeeded()
            self.refreshRowHighlighting()
            for row in 0..<tableView.numberOfRows {
                if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? FavoriteSidebarCellView {
                    cell.needsLayout = true
                    cell.layoutSubtreeIfNeeded()
                }
            }
        }
    }
    
    func item(at row: Int) -> FavoriteItem? {
        let items = parent.favoritesStore.items
        guard row >= 0, row < items.count else { return nil }
        return items[row]
    }
    
    func selectPath(_ path: String) {
        parent.path = path
        refreshRowHighlighting()
    }
    
    func refreshRowHighlighting() {
        guard let tableView else { return }
        for row in 0..<tableView.numberOfRows {
            guard let item = item(at: row) else { continue }
            let selected = parent.isSelected(item.path)
            
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? FavoriteSidebarRowView {
                rowView.isFavoriteSelected = selected
                rowView.updateTooltip(parent.showsTitle ? nil : item.name)
            }
            if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: true) as? FavoriteSidebarCellView {
                cell.configure(item: item, showsTitle: parent.showsTitle, isSelected: selected)
            }
        }
    }
    
    // MARK: Data source
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        parent.favoritesStore.items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let item = item(at: row) else { return nil }
        
        let cellID = NSUserInterfaceItemIdentifier("FavoriteSidebarCell")
        let cell: FavoriteSidebarCellView
        if let reused = tableView.makeView(withIdentifier: cellID, owner: self) as? FavoriteSidebarCellView {
            cell = reused
        } else {
            cell = FavoriteSidebarCellView()
            cell.identifier = cellID
        }
        
        cell.configure(
            item: item,
            showsTitle: parent.showsTitle,
            isSelected: parent.isSelected(item.path)
        )
        return cell
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = FavoriteSidebarRowView()
        rowView.controller = self
        rowView.rowIndex = row
        if let item = item(at: row) {
            rowView.isFavoriteSelected = parent.isSelected(item.path)
            rowView.updateTooltip(parent.showsTitle ? nil : item.name)
        }
        return rowView
    }
    
    func makeContextMenu(for row: Int) -> NSMenu? {
        guard let item = item(at: row) else { return nil }
        
        let menu = NSMenu()
        let removeItem = menu.addItem(
            withTitle: "取消收藏",
            action: #selector(removeFavorite(_:)),
            keyEquivalent: ""
        )
        removeItem.target = self
        removeItem.representedObject = item.path
        return menu
    }
    
    func handleRightMouseDown(_ event: NSEvent) {
        RailTooltipPresenter.hide()
        guard let tableView else { return }
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
        guard row >= 0 else { return }
        
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        if let item = item(at: row) {
            selectPath(item.path)
        }
        
        if let menu = makeContextMenu(for: row) {
            NSMenu.popUpContextMenu(menu, with: event, for: tableView)
        }
    }
    
    func tableView(_ tableView: NSTableView, menuFor event: NSEvent) -> NSMenu? {
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
        return makeContextMenu(for: row)
    }
    
    @objc private func removeFavorite(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        parent.favoritesStore.remove(path: path)
        syncFromParent()
    }
    
    // MARK: Reorder drag source
    
    func beginReorderDrag(forRow row: Int, event: NSEvent, in rowView: NSView) {
        guard let tableView, let item = item(at: row) else { return }
        RailTooltipPresenter.hide()
        reorderDragRow = row
        
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.path, forType: FavoriteSidebarPasteboard.reorderType)
        
        let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: true)
        let snapshot = cell?.snapshotForDrag() ?? rowView.snapshotForDrag()
        let ghostSize = snapshot?.size ?? rowView.bounds.size
        
        // 与文件列表一致：以鼠标位置为锚点，在 tableView 坐标系中设置拖影。
        let mousePoint = tableView.convert(event.locationInWindow, from: nil)
        let frame = NSRect(
            x: mousePoint.x - ghostSize.width / 2,
            y: mousePoint.y - ghostSize.height / 2,
            width: max(ghostSize.width, 1),
            height: max(ghostSize.height, 1)
        )
        
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(frame, contents: snapshot)
        
        let session = tableView.beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }
    
    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        _ = session
        _ = context
        return .move
    }
    
    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        _ = session
        _ = screenPoint
        _ = operation
        reorderDragRow = -1
        clearDropIndicator()
    }
    
    // MARK: Drop destination
    
    func draggingUpdated(_ info: NSDraggingInfo) -> NSDragOperation {
        guard let tableView else { return [] }
        let pasteboard = info.draggingPasteboard
        
        if isReorderDrag(pasteboard) {
            return updateReorderDrop(info, in: tableView)
        }
        
        let urls = FileDragDrop.fileURLs(from: pasteboard)
        if !urls.isEmpty {
            return updateFileDrop(info, in: tableView)
        }
        
        return []
    }
    
    func draggingExited() {
        clearDropIndicator()
    }
    
    func performDragOperation(_ info: NSDraggingInfo) -> Bool {
        let pasteboard = info.draggingPasteboard
        
        if isReorderDrag(pasteboard) {
            let result = acceptReorderDrop(pasteboard)
            clearDropIndicator()
            return result
        }
        
        let urls = FileDragDrop.fileURLs(from: pasteboard)
        if !urls.isEmpty {
            let destinationPath = destinationPathForPendingDrop()
            let copy = FileDragDrop.shouldCopyFromDraggingInfo(info)
            let insertBefore = addableFavoriteDirectoryURLs(from: urls).isEmpty
                ? nil
                : pendingInsertBeforeIndex
            parent.onDropURLs(urls, destinationPath, copy, insertBefore)
            clearDropIndicator()
            return true
        }
        
        clearDropIndicator()
        return false
    }
    
    private func isReorderDrag(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadItem(withDataConformingToTypes: [FavoriteSidebarPasteboard.reorderType.rawValue])
    }
    
    private func updateReorderDrop(_ info: NSDraggingInfo, in tableView: FavoritesTableView) -> NSDragOperation {
        guard let draggedPath = info.draggingPasteboard.string(forType: FavoriteSidebarPasteboard.reorderType) else {
            return []
        }
        
        let location = tableView.convert(info.draggingLocation, from: nil)
        let row = tableView.row(at: location)
        
        if row >= 0,
           let target = item(at: row),
           FavoritesStore.pathsRepresentSameLocation(draggedPath, target.path) {
            clearDropIndicator()
            return []
        }
        
        let insertBefore = insertBeforeIndex(for: location, in: tableView)
        applyInsertDropIndicator(insertBefore: insertBefore, in: tableView)
        return .move
    }
    
    private func updateFileDrop(_ info: NSDraggingInfo, in tableView: FavoritesTableView) -> NSDragOperation {
        let urls = FileDragDrop.fileURLs(from: info.draggingPasteboard)
        let location = tableView.convert(info.draggingLocation, from: nil)
        let row = tableView.row(at: location)
        
        let addableDirectories = addableFavoriteDirectoryURLs(from: urls)
        if !addableDirectories.isEmpty {
            let insertBefore = insertBeforeIndex(for: location, in: tableView)
            applyInsertDropIndicator(insertBefore: insertBefore, in: tableView)
            return FileDragDrop.dragOperation(for: info)
        }
        
        clearDropIndicator()
        if row >= 0 {
            pendingDropRow = row
        } else if tableView.numberOfRows > 0 {
            pendingDropRow = tableView.numberOfRows - 1
        } else {
            pendingDropRow = -1
        }
        pendingInsertBeforeIndex = -1
        
        return FileDragDrop.dragOperation(for: info)
    }
    
    private func addableFavoriteDirectoryURLs(from urls: [URL]) -> [URL] {
        urls.filter { url in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  !FileListApplicationBundle.isBundle(path: url.path),
                  !parent.favoritesStore.contains(path: url.path) else {
                return false
            }
            return true
        }
    }
    
    private func insertBeforeIndex(for location: NSPoint, in tableView: NSTableView) -> Int {
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return 0 }
        
        let row = tableView.row(at: location)
        if row < 0 {
            return rowCount
        }
        
        let rowRect = tableView.rect(ofRow: row)
        return location.y < rowRect.midY ? row : row + 1
    }
    
    private func applyInsertDropIndicator(insertBefore: Int, in tableView: FavoritesTableView) {
        let clamped = min(max(insertBefore, 0), tableView.numberOfRows)
        pendingInsertBeforeIndex = clamped
        pendingDropRow = clamped > 0 ? clamped - 1 : 0
        tableView.setDropRow(clamped, dropOperation: .above)
        tableView.showDropInsertionLine(beforeRow: clamped)
    }
    
    private func acceptReorderDrop(_ pasteboard: NSPasteboard) -> Bool {
        guard let draggedPath = pasteboard.string(forType: FavoriteSidebarPasteboard.reorderType) else {
            return false
        }
        
        let items = parent.favoritesStore.items
        guard let fromIndex = items.firstIndex(where: {
            FavoritesStore.pathsRepresentSameLocation($0.path, draggedPath)
        }) else {
            return false
        }
        
        let insertIndex: Int
        if pendingInsertBeforeIndex >= 0 {
            insertIndex = min(max(pendingInsertBeforeIndex, 0), items.count)
        } else {
            insertIndex = items.count
        }
        
        var targetIndex = insertIndex
        if fromIndex < targetIndex {
            targetIndex -= 1
        }
        guard targetIndex != fromIndex else { return true }
        
        parent.favoritesStore.moveItem(withPath: draggedPath, toInsertBefore: insertIndex)
        syncFromParent()
        return true
    }
    
    private func destinationPathForPendingDrop() -> String {
        let items = parent.favoritesStore.items
        guard !items.isEmpty else { return "" }
        let row = pendingDropRow < 0 ? 0 : min(pendingDropRow, items.count - 1)
        return items[row].path
    }
    
    private func clearDropIndicator() {
        pendingDropRow = -1
        pendingInsertBeforeIndex = -1
        tableView?.setDropRow(-1, dropOperation: .on)
        tableView?.hideDropInsertionLine()
    }
}

private final class FavoriteDropInsertionLineView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 1, yRadius: 1).fill()
    }
}

// MARK: - Views

private final class FavoriteSidebarCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let background = NSBox()
    private var iconLeadingConstraint: NSLayoutConstraint?
    private var iconRailCenterConstraint: NSLayoutConstraint?
    private var titleLeadingConstraint: NSLayoutConstraint?
    private var backgroundLeadingConstraint: NSLayoutConstraint?
    private var backgroundTrailingConstraint: NSLayoutConstraint?
    private var backgroundWidthConstraint: NSLayoutConstraint?
    private var showsTitleLayout = true
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        clipsToBounds = false
        background.boxType = .custom
        background.cornerRadius = 6
        background.borderWidth = 0
        background.fillColor = .clear
        background.translatesAutoresizingMaskIntoConstraints = false
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.lineBreakMode = .byTruncatingTail
        titleField.font = .systemFont(ofSize: NSFont.systemFontSize)
        titleField.textColor = .labelColor
        
        addSubview(background)
        addSubview(iconView)
        addSubview(titleField)
        
        iconLeadingConstraint = iconView.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: FavoriteSidebarMetrics.sidebarIconLeadingInset
        )
        iconRailCenterConstraint = iconView.centerXAnchor.constraint(
            equalTo: leadingAnchor,
            constant: FavoriteSidebarMetrics.railContentWidth / 2
        )
        titleLeadingConstraint = titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8)
        
        backgroundLeadingConstraint = background.leadingAnchor.constraint(equalTo: leadingAnchor)
        backgroundTrailingConstraint = background.trailingAnchor.constraint(equalTo: trailingAnchor)
        backgroundWidthConstraint = background.widthAnchor.constraint(
            equalToConstant: FavoriteSidebarMetrics.railContentWidth
        )
        
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -FavoriteSidebarMetrics.rowContentInset),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    func configure(item: FavoriteItem, showsTitle: Bool, isSelected: Bool) {
        let image = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil)
        image?.isTemplate = true
        iconView.image = image
        iconView.contentTintColor = isSelected ? .controlAccentColor : .labelColor
        
        titleField.stringValue = showsTitle ? item.name : ""
        titleField.isHidden = !showsTitle
        titleField.alphaValue = showsTitle ? 1 : 0
        titleField.textColor = isSelected ? .controlAccentColor : .labelColor
        
        iconLeadingConstraint?.isActive = showsTitle
        iconRailCenterConstraint?.isActive = !showsTitle
        titleLeadingConstraint?.isActive = showsTitle
        showsTitleLayout = showsTitle
        
        if showsTitle {
            backgroundLeadingConstraint?.isActive = true
            backgroundTrailingConstraint?.isActive = true
            backgroundWidthConstraint?.isActive = false
        } else {
            backgroundLeadingConstraint?.isActive = true
            backgroundTrailingConstraint?.isActive = false
            backgroundWidthConstraint?.isActive = true
        }
        
        background.fillColor = isSelected
            ? NSColor.unemphasizedSelectedContentBackgroundColor
            : .clear
    }
    
    override func layout() {
        super.layout()
        guard !showsTitleLayout else { return }
        let trackWidth = min(bounds.width, FavoriteSidebarMetrics.railContentWidth)
        iconRailCenterConstraint?.constant = max(trackWidth / 2, 8)
        backgroundWidthConstraint?.constant = trackWidth
    }
}

private final class FavoriteSidebarRowView: NSTableRowView {
    weak var controller: FavoritesSidebarController?
    var rowIndex = -1
    var isFavoriteSelected = false
    
    private var mouseDownLocation: NSPoint = .zero
    private let dragThreshold: CGFloat = 4
    private var didBeginDrag = false
    private var tooltipText: String?
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clipsToBounds = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = false
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        // 选中样式由 cell 自己绘制。
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
    }
    
    func updateTooltip(_ text: String?) {
        let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = normalized?.isEmpty == false ? normalized : nil
        guard tooltipText != next else { return }
        tooltipText = next
        toolTip = nil
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
        guard tooltipText != nil else { return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard let tooltipText else { return }
        RailTooltipPresenter.show(text: tooltipText, anchor: self)
    }
    
    override func mouseExited(with event: NSEvent) {
        RailTooltipPresenter.hide()
    }
    
    deinit {
        RailTooltipPresenter.hide()
    }
    
    private func selectRowIfNeeded() {
        guard let controller, rowIndex >= 0, let item = controller.item(at: rowIndex) else { return }
        controller.selectPath(item.path)
        controller.tableView?.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            controller?.handleRightMouseDown(event)
            return
        }
        mouseDownLocation = event.locationInWindow
        didBeginDrag = false
        selectRowIfNeeded()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        controller?.handleRightMouseDown(event)
    }
    
    override func mouseUp(with event: NSEvent) {
        // 选中已在 mouseDown 时完成。
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard !didBeginDrag else { return }
        let current = event.locationInWindow
        let dx = current.x - mouseDownLocation.x
        let dy = current.y - mouseDownLocation.y
        guard dx * dx + dy * dy >= dragThreshold * dragThreshold else { return }
        didBeginDrag = true
        controller?.beginReorderDrag(forRow: rowIndex, event: event, in: self)
    }
}

final class FavoritesTableView: NSTableView {
    weak var controller: FavoritesSidebarController?
    private let dropInsertionLine = FavoriteDropInsertionLineView()
    
    func showDropInsertionLine(beforeRow insertBefore: Int) {
        let y: CGFloat
        let rowCount = numberOfRows
        if rowCount == 0 {
            y = 0
        } else if insertBefore <= 0 {
            y = rect(ofRow: 0).minY
        } else if insertBefore >= rowCount {
            y = rect(ofRow: rowCount - 1).maxY
        } else {
            y = rect(ofRow: insertBefore).minY
        }
        
        let horizontalInset: CGFloat = configuredShowsTitle ? 4 : 2
        dropInsertionLine.frame = NSRect(
            x: horizontalInset,
            y: y - 1,
            width: max(bounds.width - horizontalInset * 2, 4),
            height: 2
        )
        if dropInsertionLine.superview == nil {
            addSubview(dropInsertionLine)
        }
        dropInsertionLine.isHidden = false
    }
    
    func hideDropInsertionLine() {
        dropInsertionLine.isHidden = true
    }
    
    override func rightMouseDown(with event: NSEvent) {
        controller?.handleRightMouseDown(event)
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        guard !configuredShowsTitle else { return }
        guard abs(oldSize.width - frame.width) > 0.5 else { return }
        controller?.refreshRowHighlighting()
    }
    
    override var intrinsicContentSize: NSSize {
        let rowCount = max(numberOfRows, 0)
        guard rowCount > 0 else {
            return NSSize(
                width: configuredShowsTitle ? NSView.noIntrinsicMetric : FavoriteSidebarMetrics.railContentWidth,
                height: 0
            )
        }
        let height = CGFloat(rowCount) * rowHeight + CGFloat(max(rowCount - 1, 0)) * intercellSpacing.height
        let width = configuredShowsTitle
            ? NSView.noIntrinsicMetric
            : FavoriteSidebarMetrics.railContentWidth
        return NSSize(width: width, height: height)
    }
    
    private var isInstalled = false
    private(set) var configuredShowsTitle = true
    
    func installIfNeeded(showsTitle: Bool) {
        guard !isInstalled else {
            applyShowsTitleLayout(showsTitle)
            return
        }
        isInstalled = true
        install(showsTitle: showsTitle)
    }
    
    func applyShowsTitleLayout(_ showsTitle: Bool) {
        configuredShowsTitle = showsTitle
        rowHeight = showsTitle ? FavoriteSidebarMetrics.sidebarRowHeight : FavoriteSidebarMetrics.railRowHeight
        rowSizeStyle = .custom
        style = showsTitle ? .fullWidth : .plain
        columnAutoresizingStyle = showsTitle
            ? .uniformColumnAutoresizingStyle
            : .noColumnAutoresizing
        clipsToBounds = showsTitle
        
        guard let column = tableColumns.first else { return }
        if showsTitle {
            column.resizingMask = .autoresizingMask
            column.minWidth = 100
            column.maxWidth = 10_000
            column.width = FavoriteSidebarMetrics.sidebarColumnWidth
        } else {
            column.resizingMask = []
            column.minWidth = FavoriteSidebarMetrics.railContentWidth
            column.maxWidth = FavoriteSidebarMetrics.railContentWidth
            column.width = FavoriteSidebarMetrics.railContentWidth
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
        layoutSubtreeIfNeeded()
    }
    
    private func install(showsTitle: Bool) {
        headerView = nil
        backgroundColor = .clear
        focusRingType = .none
        selectionHighlightStyle = .none
        rowSizeStyle = .custom
        allowsEmptySelection = true
        allowsMultipleSelection = false
        usesAlternatingRowBackgroundColors = false
        intercellSpacing = .zero
        clipsToBounds = showsTitle
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FavoriteColumn"))
        addTableColumn(column)
        applyShowsTitleLayout(showsTitle)
        
        registerForDraggedTypes(FavoriteSidebarPasteboard.draggedTypes)
        setDraggingSourceOperationMask(.move, forLocal: true)
    }
    
    // 与缩略图列表一致：在 view 层实现 NSDraggingDestination，比仅依赖 delegate 更可靠。
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        controller?.draggingUpdated(sender) ?? []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        controller?.draggingUpdated(sender) ?? []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        controller?.draggingExited()
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        controller?.draggingUpdated(sender) != []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        controller?.performDragOperation(sender) ?? false
    }
}

// MARK: - SwiftUI bridge

struct FavoritesSidebarHost: NSViewRepresentable {
    @ObservedObject var favoritesStore: FavoritesStore
    @Binding var path: String
    var showsTitle: Bool
    var isSelected: (String) -> Bool
    var onDropURLs: ([URL], String, Bool, Int?) -> Void
    
    func makeCoordinator() -> FavoritesSidebarController {
        FavoritesSidebarController(parent: self)
    }
    
    func makeNSView(context: Context) -> FavoritesTableView {
        let tableView = FavoritesTableView()
        tableView.installIfNeeded(showsTitle: showsTitle)
        tableView.controller = context.coordinator
        context.coordinator.tableView = tableView
        context.coordinator.parent = self
        context.coordinator.bootstrap(showsTitle: showsTitle)
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.reloadData()
        if !showsTitle {
            context.coordinator.scheduleLayoutRefreshAfterModeChange()
        }
        return tableView
    }
    
    func updateNSView(_ tableView: FavoritesTableView, context: Context) {
        let previousShowsTitle = tableView.configuredShowsTitle
        context.coordinator.parent = self
        tableView.installIfNeeded(showsTitle: showsTitle)
        context.coordinator.syncFromParent()
        if previousShowsTitle != showsTitle {
            context.coordinator.scheduleLayoutRefreshAfterModeChange()
        }
    }
    
    static func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: FavoritesTableView,
        context: Context
    ) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        let width: CGFloat
        if nsView.configuredShowsTitle {
            width = proposal.width ?? FavoriteSidebarMetrics.sidebarColumnWidth
        } else {
            width = FavoriteSidebarMetrics.railContentWidth
        }
        let height = intrinsic.height == NSView.noIntrinsicMetric ? 0 : intrinsic.height
        return CGSize(width: width, height: height)
    }
}

// MARK: - Helpers

private extension NSView {
    func snapshotForDrag() -> NSImage? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        return bitmapImageRepForCachingDisplay(in: bounds).map { rep in
            cacheDisplay(in: bounds, to: rep)
            let image = NSImage(size: bounds.size)
            image.addRepresentation(rep)
            return image
        }
    }
}
