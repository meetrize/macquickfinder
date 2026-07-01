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
    /// 与 `LeftPanelLayoutConstants.railWidth`（44）减去 `SidebarRailView` 左右 padding（8）对齐。
    static let contentWidth: CGFloat = 36
    /// 与侧栏 `SidebarRow` 及收藏夹表格行高一致（body + vertical 4）。
    static let rowHeight: CGFloat = 24
    /// 侧栏模式：收藏列表与 `SidebarView` 水平 padding 对齐，选中背景左缘距面板 8pt。
    static let sidebarContentLeadingBleed: CGFloat = 0
    /// 侧栏模式：收藏列表向右外扩。
    static let sidebarContentTrailingBleed: CGFloat = 0
    /// 工具栏模式：收藏列表向左外扩。
    static let railContentLeadingBleed: CGFloat = 3
    /// 工具栏模式：收藏列表向右外扩。
    static let railContentTrailingBleed: CGFloat = 2
}

private enum FavoriteSidebarMetrics {
    static let railContentWidth = FavoriteSidebarRailLayout.contentWidth
    static let sidebarColumnWidth: CGFloat = 240
    /// 与 `SidebarRow`（body + vertical 4）视觉行高对齐；侧栏与工具栏共用。
    static let rowHeight: CGFloat = FavoriteSidebarRailLayout.rowHeight
    static let sidebarRowHeight: CGFloat = rowHeight
    static let railRowHeight: CGFloat = rowHeight
    static let rowContentInset: CGFloat = 8
    static let selectionCornerRadius: CGFloat = 6
    /// 选中背景相对内容区向左偏移（左右边缘同步左移）。
    static let selectionBackgroundLeadingOffset: CGFloat = -5
    /// 侧栏模式下图标左边距（相对 `SidebarRow` 内容区再向左 5pt）。
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
    private var dropHighlightRow: Int?
    private var reorderDragRow = -1
    /// 鼠标放下瞬间 `draggingUpdated` 可能清掉 `pendingDropRow`，保留最后一次有效的移入目录行。
    private var lastValidFileDropRow = -1
    
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
            tableView.redisplayVisibleRowSelections()
        }
    }
    
    func item(at row: Int) -> FavoriteItem? {
        let items = parent.favoritesStore.items
        guard row >= 0, row < items.count else { return nil }
        return items[row]
    }
    
    func selectPath(_ path: String) {
        parent.onNavigateToDirectory(path)
        refreshRowHighlighting()
    }
    
    func refreshRowHighlighting() {
        guard let tableView else { return }
        for row in 0..<tableView.numberOfRows {
            guard let item = item(at: row) else { continue }
            let selected = parent.isSelected(item.path)
            
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? FavoriteSidebarRowView {
                rowView.isFavoriteSelected = selected
                rowView.isDropTargetRow = row == dropHighlightRow
                rowView.showsRailLayout = !parent.showsTitle
                rowView.updateTooltip(parent.showsTitle ? nil : item.displayName)
                rowView.needsDisplay = true
            }
            if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: true) as? FavoriteSidebarCellView {
                cell.configure(item: item, showsTitle: parent.showsTitle, isSelected: selected)
                cell.isDropTargetRow = row == dropHighlightRow
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
        cell.isDropTargetRow = row == dropHighlightRow
        return cell
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = FavoriteSidebarRowView()
        rowView.controller = self
        rowView.rowIndex = row
        rowView.showsRailLayout = !parent.showsTitle
        if let item = item(at: row) {
            rowView.isFavoriteSelected = parent.isSelected(item.path)
            rowView.isDropTargetRow = row == dropHighlightRow
            rowView.updateTooltip(parent.showsTitle ? nil : item.displayName)
        }
        return rowView
    }
    
    func makeContextMenu(for row: Int) -> NSMenu? {
        guard let item = item(at: row) else { return nil }
        
        let menu = NSMenu()
        let removeItem = menu.addItem(
            withTitle: L10n.Action.removeFavorite,
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
        lastValidFileDropRow = -1
        clearDropIndicator()
    }
    
    func performDragOperation(_ info: NSDraggingInfo) -> Bool {
        let pasteboard = info.draggingPasteboard
        
        if isReorderDrag(pasteboard) {
            let result = acceptReorderDrop(pasteboard)
            lastValidFileDropRow = -1
            clearDropIndicator()
            return result
        }
        
        let urls = FileDragDrop.fileURLs(from: pasteboard)
        if !urls.isEmpty {
            let insertBefore = pendingInsertBeforeIndex >= 0 ? pendingInsertBeforeIndex : nil
            guard let dropRow = effectiveFileDropRow(),
                  let item = item(at: dropRow) else {
                lastValidFileDropRow = -1
                clearDropIndicator()
                return false
            }
            if insertBefore == nil, !canDropOntoRow(dropRow, urls: urls) {
                lastValidFileDropRow = -1
                clearDropIndicator()
                return false
            }
            let destinationPath = item.resolvedDirectoryPath
            let copy = FileDragDrop.shouldCopyFromDraggingInfo(info)
            parent.onDropURLs(urls, destinationPath, copy, insertBefore)
            lastValidFileDropRow = -1
            clearDropIndicator()
            return true
        }
        
        lastValidFileDropRow = -1
        clearDropIndicator()
        return false
    }
    
    private func isReorderDrag(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.string(forType: FavoriteSidebarPasteboard.reorderType) != nil
    }
    
    private func updateReorderDrop(_ info: NSDraggingInfo, in tableView: FavoritesTableView) -> NSDragOperation {
        guard let draggedPath = info.draggingPasteboard.string(forType: FavoriteSidebarPasteboard.reorderType) else {
            return []
        }
        
        let location = tableView.convert(info.draggingLocation, from: nil)
        let row = tableView.row(at: location)
        
        if row >= 0,
           let target = item(at: row),
           FavoritesSidebarDropPolicy.shouldRejectReorder(
               draggedPath: draggedPath,
               ontoTargetPath: target.path
           ) {
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
        
        if row >= 0, shouldDropFilesOntoFavoriteRow(location, row: row, in: tableView, urls: urls) {
            applyRowDropIndicator(row: row, in: tableView)
            if canDropOntoRow(row, urls: urls) {
                return FileDragDrop.dragOperation(for: info)
            }
            return []
        }
        
        let addableDirectories = addableFavoriteDirectoryURLs(from: urls)
        if !addableDirectories.isEmpty {
            let insertBefore = insertBeforeIndex(for: location, in: tableView)
            applyInsertDropIndicator(insertBefore: insertBefore, in: tableView)
            return FileDragDrop.dragOperation(for: info)
        }
        
        clearDropIndicator()
        return []
    }
    
    /// 移入收藏目录：可移入时整行有效；否则仅中央区域用于无效目标的视觉反馈。
    private func shouldDropFilesOntoFavoriteRow(
        _ location: NSPoint,
        row: Int,
        in tableView: NSTableView,
        urls: [URL]
    ) -> Bool {
        let rowRect = tableView.rect(ofRow: row)
        guard rowRect.contains(location) else { return false }
        
        if canDropOntoRow(row, urls: urls) {
            return true
        }
        return isDropOntoRowCenter(location, row: row, in: tableView)
    }
    
    private func isDropOntoRowCenter(_ location: NSPoint, row: Int, in tableView: NSTableView) -> Bool {
        let rowRect = tableView.rect(ofRow: row)
        guard rowRect.contains(location) else { return false }
        return FavoritesSidebarDropPolicy.isDropOntoRowCenter(
            locationY: location.y,
            rowMinY: rowRect.minY,
            rowHeight: rowRect.height
        )
    }

    private func canDropOntoRow(_ row: Int, urls: [URL]) -> Bool {
        guard let item = item(at: row) else { return false }
        return FavoritesSidebarDropPolicy.canDropOntoFavorite(
            destinationPath: item.resolvedDirectoryPath,
            sourcePaths: urls.map(\.path)
        )
    }
    
    func prepareForFileDrop(_ info: NSDraggingInfo) -> Bool {
        _ = draggingUpdated(info)
        let urls = FileDragDrop.fileURLs(from: info.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        if pendingInsertBeforeIndex >= 0 { return true }
        guard let row = effectiveFileDropRow() else { return false }
        return canDropOntoRow(row, urls: urls)
    }
    
    /// 解析当前应移入的收藏行；`pendingDropRow` 被放下时的最后一次 `draggingUpdated` 清掉时回退到 `lastValidFileDropRow`。
    private func effectiveFileDropRow() -> Int? {
        let rowCount = tableView?.numberOfRows ?? parent.favoritesStore.items.count
        guard rowCount > 0 else { return nil }
        
        if pendingInsertBeforeIndex >= 0 {
            return min(pendingInsertBeforeIndex, rowCount - 1)
        }
        if pendingDropRow >= 0 {
            return pendingDropRow
        }
        if lastValidFileDropRow >= 0, lastValidFileDropRow < rowCount {
            return lastValidFileDropRow
        }
        return nil
    }
    
    private func applyRowDropIndicator(row: Int, in tableView: FavoritesTableView) {
        pendingDropRow = row
        pendingInsertBeforeIndex = -1
        lastValidFileDropRow = row
        tableView.hideDropInsertionLine()
        tableView.setDropRow(row, dropOperation: .on)
        setDropHighlight(row: row)
    }
    
    private func setDropHighlight(row: Int?) {
        guard dropHighlightRow != row else { return }
        let previous = dropHighlightRow
        dropHighlightRow = row
        
        if let previous, let tableView {
            applyDropTargetHighlight(false, row: previous, in: tableView)
        }
        if let row, let tableView {
            applyDropTargetHighlight(true, row: row, in: tableView)
        }
    }
    
    private func applyDropTargetHighlight(_ highlighted: Bool, row: Int, in tableView: FavoritesTableView) {
        if let rowView = tableView.rowView(atRow: row, makeIfNecessary: highlighted) as? FavoriteSidebarRowView {
            rowView.isDropTargetRow = highlighted
            rowView.needsDisplay = true
        }
        if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: highlighted) as? FavoriteSidebarCellView {
            cell.isDropTargetRow = highlighted
            cell.layoutSubtreeIfNeeded()
        }
    }
    
    private func clearDropHighlight() {
        setDropHighlight(row: nil)
    }
    
    private func addableFavoriteDirectoryURLs(from urls: [URL]) -> [URL] {
        FavoritesSidebarDropPolicy.filterAddableDirectoryURLs(urls) { path in
            parent.favoritesStore.contains(path: path)
        }
    }
    
    private func insertBeforeIndex(for location: NSPoint, in tableView: NSTableView) -> Int {
        let rowCount = tableView.numberOfRows
        let row = tableView.row(at: location)
        let rowMidY: CGFloat?
        if row >= 0, row < rowCount {
            rowMidY = tableView.rect(ofRow: row).midY
        } else {
            rowMidY = nil
        }
        return FavoritesSidebarDropPolicy.insertBeforeIndex(
            locationY: location.y,
            rowAtLocation: row,
            rowCount: rowCount,
            rowMidY: rowMidY
        )
    }
    
    private func applyInsertDropIndicator(insertBefore: Int, in tableView: FavoritesTableView) {
        let clamped = min(max(insertBefore, 0), tableView.numberOfRows)
        pendingInsertBeforeIndex = clamped
        pendingDropRow = tableView.numberOfRows > 0 ? min(clamped, tableView.numberOfRows - 1) : -1
        clearDropHighlight()
        tableView.setDropRow(clamped, dropOperation: .above)
        tableView.showDropInsertionLine(beforeRow: clamped)
    }
    
    private func acceptReorderDrop(_ pasteboard: NSPasteboard) -> Bool {
        guard let draggedPath = pasteboard.string(forType: FavoriteSidebarPasteboard.reorderType) else {
            return false
        }
        
        let items = parent.favoritesStore.items
        guard items.contains(where: {
            FavoritesStore.pathsRepresentSameLocation($0.path, draggedPath)
        }) else {
            return false
        }
        
        let insertIndex: Int
        if pendingInsertBeforeIndex >= 0 {
            insertIndex = FavoritesSidebarDropPolicy.clampedInsertIndex(
                pendingInsertBeforeIndex,
                itemCount: items.count
            )
        } else {
            insertIndex = items.count
        }

        parent.favoritesStore.moveItem(withPath: draggedPath, toInsertBefore: insertIndex)
        syncFromParent()
        return true
    }

    private func clearDropIndicator() {
        pendingDropRow = -1
        pendingInsertBeforeIndex = -1
        clearDropHighlight()
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

/// 按可用宽度生成尾部省略文本。
private enum FavoriteSidebarTitleTruncation {
    static func displayString(_ string: String, font: NSFont, maxWidth: CGFloat) -> String {
        guard maxWidth > 4, !string.isEmpty else { return "" }
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        if (string as NSString).size(withAttributes: attrs).width <= maxWidth {
            return string
        }
        let ellipsis = "…"
        var trimmed = string
        while !trimmed.isEmpty {
            let candidate = trimmed + ellipsis
            if (candidate as NSString).size(withAttributes: attrs).width <= maxWidth {
                return candidate
            }
            trimmed.removeLast()
        }
        return ellipsis
    }
}

/// 自绘单行尾部省略标题。
private final class FavoriteSidebarTruncatingTitleView: NSView {
    var text: String = "" {
        didSet { guard text != oldValue else { return }; needsDisplay = true }
    }
    var textColor: NSColor = .labelColor {
        didSet { needsDisplay = true }
    }
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize) {
        didSet { needsDisplay = true }
    }
    var maxTextWidth: CGFloat = 0 {
        didSet {
            let rounded = max(0, maxTextWidth)
            guard abs(rounded - oldValue) > 0.5 else { return }
            needsDisplay = true
        }
    }
    
    override var isFlipped: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        guard maxTextWidth > 1, !text.isEmpty else { return }
        let display = FavoriteSidebarTitleTruncation.displayString(text, font: font, maxWidth: maxTextWidth)
        guard !display.isEmpty else { return }
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let lineHeight = ceil(font.boundingRectForFont.height)
        let drawRect = NSRect(
            x: 0,
            y: floor((bounds.height - lineHeight) / 2),
            width: maxTextWidth,
            height: lineHeight
        )
        (display as NSString).draw(in: drawRect, withAttributes: attrs)
    }
}

private final class FavoriteSidebarCellView: NSTableCellView {
    private let selectionBackgroundView = NSView()
    private let iconView = NSImageView()
    private let titleView = FavoriteSidebarTruncatingTitleView()
    private var showsSidebarTitle = true
    private var isFavoriteSelected = false
    var isDropTargetRow = false {
        didSet {
            guard oldValue != isDropTargetRow else { return }
            needsLayout = true
        }
    }
    
    override var isFlipped: Bool { true }
    
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
        
        selectionBackgroundView.wantsLayer = true
        selectionBackgroundView.layer?.masksToBounds = true
        selectionBackgroundView.isHidden = true
        
        iconView.imageScaling = .scaleProportionallyDown
        
        addSubview(selectionBackgroundView)
        addSubview(iconView)
        addSubview(titleView)
    }
    
    func configure(item: FavoriteItem, showsTitle: Bool, isSelected: Bool) {
        let image = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil)
        image?.isTemplate = true
        iconView.image = image
        iconView.contentTintColor = isSelected ? .controlAccentColor : .labelColor
        
        showsSidebarTitle = showsTitle
        isFavoriteSelected = isSelected && showsTitle
        titleView.text = showsTitle ? item.displayName : ""
        titleView.isHidden = !showsTitle
        titleView.textColor = isSelected ? .controlAccentColor : .labelColor
        
        needsLayout = true
    }
    
    override var backgroundStyle: NSView.BackgroundStyle {
        get { .normal }
        set { }
    }
    
    private func favoritesTableView() -> FavoritesTableView? {
        var view: NSView? = self
        while let current = view {
            if let table = current as? FavoritesTableView { return table }
            view = current.superview
        }
        return nil
    }
    
    private func effectiveContentWidth() -> CGFloat {
        let cellWidth = bounds.width
        guard let table = favoritesTableView() else { return cellWidth }
        let limit = table.resolvedContentWidth
        guard limit > 0 else { return cellWidth }
        return min(cellWidth, limit)
    }
    
    override func layout() {
        super.layout()
        let height = bounds.height
        let contentWidth = effectiveContentWidth()
        let iconSize: CGFloat = 16
        
        if showsSidebarTitle {
            let leading = FavoriteSidebarMetrics.sidebarIconLeadingInset
            let radius = min(
                FavoriteSidebarMetrics.selectionCornerRadius,
                contentWidth / 2,
                height / 2
            )
            
            // 与 SidebarRow 一致：拖放目标高亮优先于选中灰色背景。
            let showsHighlightBackground = isDropTargetRow || isFavoriteSelected
            selectionBackgroundView.isHidden = !showsHighlightBackground
            if showsHighlightBackground, radius > 0 {
                selectionBackgroundView.frame = NSRect(
                    x: FavoriteSidebarMetrics.selectionBackgroundLeadingOffset,
                    y: 0,
                    width: contentWidth,
                    height: height
                )
                selectionBackgroundView.layer?.cornerRadius = radius
                if isDropTargetRow {
                    selectionBackgroundView.layer?.backgroundColor = NSColor
                        .controlAccentColor
                        .withAlphaComponent(0.18)
                        .cgColor
                } else {
                    selectionBackgroundView.layer?.backgroundColor = NSColor
                        .unemphasizedSelectedContentBackgroundColor
                        .cgColor
                }
            }
            
            iconView.frame = NSRect(
                x: leading,
                y: (height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            let titleX = leading + iconSize + 8
            let titleWidth = max(0, contentWidth - titleX - FavoriteSidebarMetrics.rowContentInset)
            titleView.frame = NSRect(x: titleX, y: 0, width: titleWidth, height: height)
            titleView.maxTextWidth = titleWidth
        } else {
            selectionBackgroundView.isHidden = true
            let trackWidth = min(contentWidth, FavoriteSidebarMetrics.railContentWidth)
            let iconX = max(trackWidth / 2 - iconSize / 2, 0)
            iconView.frame = NSRect(
                x: iconX,
                y: (height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            titleView.frame = .zero
            titleView.maxTextWidth = 0
        }
    }
}

private final class FavoriteSidebarRowView: NSTableRowView {
    weak var controller: FavoritesSidebarController?
    var rowIndex = -1
    var isFavoriteSelected = false
    var isDropTargetRow = false {
        didSet {
            guard oldValue != isDropTargetRow else { return }
            needsDisplay = true
        }
    }
    var showsRailLayout = false
    
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
        // 选中高亮由 FavoriteSidebarCellView 绘制；拖放高亮亦在 Cell 层优先于选中态。
    }
    
    override func viewWillDraw() {
        // 阻止 NSTableRowView 在选中行上改写 Cell 的 backgroundStyle，避免覆盖自定义背景。
    }
    
    /// 拖放目标高亮矩形（选中高亮改在 `FavoriteSidebarCellView` 内绘制）。
    private func selectionHighlightRect() -> NSRect? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        guard let tableView = superview as? NSTableView else { return bounds }
        
        var width = min(bounds.width, tableView.bounds.width)
        if showsRailLayout {
            width = min(width, FavoriteSidebarMetrics.railContentWidth)
        }
        guard width > 0 else { return nil }
        return NSRect(x: 0, y: 0, width: width, height: bounds.height)
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        guard isDropTargetRow, let rect = selectionHighlightRect() else { return }
        
        let radius = min(
            FavoriteSidebarMetrics.selectionCornerRadius,
            rect.width / 2,
            rect.height / 2
        )
        guard radius > 0 else { return }
        
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
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
    /// SwiftUI 传入的可视内容宽度；列宽与单元格布局均以此为准。
    fileprivate var resolvedContentWidth: CGFloat = 0
    
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
    
    override func setFrameSize(_ newSize: NSSize) {
        let oldWidth = frame.width
        super.setFrameSize(newSize)
        guard configuredShowsTitle, abs(oldWidth - newSize.width) > 0.5 else { return }
        if resolvedContentWidth <= 0, newSize.width > 0 {
            resolvedContentWidth = newSize.width
        }
        applyResolvedContentWidth()
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        guard abs(oldSize.width - frame.width) > 0.5 else { return }
        if configuredShowsTitle, resolvedContentWidth <= 0, bounds.width > 0 {
            resolvedContentWidth = bounds.width
        }
        applyResolvedContentWidth()
        if !configuredShowsTitle {
            controller?.refreshRowHighlighting()
        }
    }
    
    fileprivate func applyAvailableContentWidth(_ width: CGFloat) {
        guard width > 0, abs(resolvedContentWidth - width) > 0.5 else {
            if width > 0, resolvedContentWidth == 0 {
                resolvedContentWidth = width
                applyResolvedContentWidth()
            }
            return
        }
        resolvedContentWidth = width
        applyResolvedContentWidth()
    }
    
    fileprivate func applyResolvedContentWidth() {
        guard configuredShowsTitle else { return }
        let width = resolvedContentWidth > 0 ? resolvedContentWidth : bounds.width
        guard width > 0, let column = tableColumns.first else { return }
        if abs(column.width - width) > 0.5 {
            column.width = width
        }
        relayoutVisibleCells()
    }
    
    private func relayoutVisibleCells() {
        guard numberOfRows > 0 else { return }
        for row in 0..<numberOfRows {
            guard let cell = view(atColumn: 0, row: row, makeIfNecessary: false) as? FavoriteSidebarCellView else {
                continue
            }
            cell.needsLayout = true
        }
    }
    
    fileprivate func redisplayVisibleRowSelections() {
        guard numberOfRows > 0 else { return }
        for row in 0..<numberOfRows {
            (rowView(atRow: row, makeIfNecessary: false) as? FavoriteSidebarRowView)?.needsDisplay = true
        }
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
        clipsToBounds = false
        
        guard let column = tableColumns.first else { return }
        if showsTitle {
            column.resizingMask = .autoresizingMask
            column.minWidth = 0
            column.maxWidth = 10_000
            if bounds.width > 0 {
                column.width = bounds.width
            }
        } else {
            column.resizingMask = []
            column.minWidth = FavoriteSidebarMetrics.railContentWidth
            column.maxWidth = FavoriteSidebarMetrics.railContentWidth
            column.width = FavoriteSidebarMetrics.railContentWidth
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
        applyResolvedContentWidth()
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
        clipsToBounds = false
        
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
        controller?.prepareForFileDrop(sender) ?? false
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
    var availableWidth: CGFloat
    var isSelected: (String) -> Bool
    var onNavigateToDirectory: (String) -> Void
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
        DispatchQueue.main.async {
            if availableWidth > 0 {
                tableView.applyAvailableContentWidth(availableWidth)
            } else {
                tableView.applyResolvedContentWidth()
            }
        }
        return tableView
    }
    
    func updateNSView(_ tableView: FavoritesTableView, context: Context) {
        let previousShowsTitle = tableView.configuredShowsTitle
        context.coordinator.parent = self
        tableView.installIfNeeded(showsTitle: showsTitle)
        context.coordinator.syncFromParent()
        if availableWidth > 0 {
            tableView.applyAvailableContentWidth(availableWidth)
        }
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
        let height = intrinsic.height == NSView.noIntrinsicMetric ? 0 : intrinsic.height
        
        if nsView.configuredShowsTitle {
            let width = context.coordinator.parent.availableWidth > 0
                ? context.coordinator.parent.availableWidth
                : (proposal.width ?? nsView.resolvedContentWidth)
            guard width > 0 else { return nil }
            return CGSize(width: width, height: height)
        }
        
        return CGSize(width: FavoriteSidebarMetrics.railContentWidth, height: height)
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
