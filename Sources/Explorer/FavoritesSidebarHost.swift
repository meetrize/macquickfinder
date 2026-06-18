import SwiftUI
import AppKit
import UniformTypeIdentifiers

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

// MARK: - Controller

@MainActor
final class FavoritesSidebarController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSDraggingSource {
    var parent: FavoritesSidebarHost
    weak var tableView: FavoritesTableView?
    
    private var lastItemPaths: [String] = []
    private var pendingDropRow = -1
    private var pendingDropOperation: NSTableView.DropOperation = .on
    private var reorderDragRow = -1
    
    init(parent: FavoritesSidebarHost) {
        self.parent = parent
    }
    
    func syncFromParent() {
        let paths = parent.favoritesStore.items.map(\.path)
        if paths != lastItemPaths {
            lastItemPaths = paths
            tableView?.reloadData()
            tableView?.invalidateIntrinsicContentSize()
        }
        refreshRowHighlighting()
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
            }
            if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? FavoriteSidebarCellView {
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
            rowView.toolTip = parent.showsTitle ? nil : item.name
        }
        return rowView
    }
    
    func tableView(_ tableView: NSTableView, menuFor event: NSEvent) -> NSMenu? {
        guard parent.showsTitle else { return nil }
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
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
    
    @objc private func removeFavorite(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        parent.favoritesStore.remove(path: path)
        syncFromParent()
    }
    
    // MARK: Reorder drag source
    
    func beginReorderDrag(forRow row: Int, event: NSEvent, in rowView: NSView) {
        guard let tableView, let item = item(at: row) else { return }
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
            parent.onDropURLs(urls, destinationPath, copy)
            clearDropIndicator()
            return true
        }
        
        clearDropIndicator()
        return false
    }
    
    private func isReorderDrag(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadItem(withDataConformingToTypes: [FavoriteSidebarPasteboard.reorderType.rawValue])
    }
    
    private func updateReorderDrop(_ info: NSDraggingInfo, in tableView: NSTableView) -> NSDragOperation {
        guard let draggedPath = info.draggingPasteboard.string(forType: FavoriteSidebarPasteboard.reorderType) else {
            return []
        }
        
        let location = tableView.convert(info.draggingLocation, from: nil)
        let row = tableView.row(at: location)
        
        if row < 0 {
            if tableView.numberOfRows == 0 { return [] }
            pendingDropRow = tableView.numberOfRows
            pendingDropOperation = .on
            tableView.setDropRow(tableView.numberOfRows - 1, dropOperation: .on)
            return .move
        }
        
        guard let target = item(at: row),
              !FavoritesStore.pathsRepresentSameLocation(draggedPath, target.path) else {
            clearDropIndicator()
            return []
        }
        
        let rowRect = tableView.rect(ofRow: row)
        if location.y < rowRect.midY {
            pendingDropRow = row
            pendingDropOperation = .above
            tableView.setDropRow(row, dropOperation: .above)
        } else {
            pendingDropRow = row
            pendingDropOperation = .on
            tableView.setDropRow(row, dropOperation: .on)
        }
        return .move
    }
    
    private func updateFileDrop(_ info: NSDraggingInfo, in tableView: NSTableView) -> NSDragOperation {
        let location = tableView.convert(info.draggingLocation, from: nil)
        let row = tableView.row(at: location)
        
        if row >= 0 {
            pendingDropRow = row
            pendingDropOperation = .on
            tableView.setDropRow(row, dropOperation: .on)
        } else if tableView.numberOfRows > 0 {
            pendingDropRow = tableView.numberOfRows - 1
            pendingDropOperation = .on
            tableView.setDropRow(pendingDropRow, dropOperation: .on)
        } else {
            pendingDropRow = -1
        }
        
        return FileDragDrop.dragOperation(for: info)
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
        
        var insertIndex: Int
        if pendingDropRow < 0 {
            insertIndex = items.count
        } else if pendingDropOperation == .on {
            insertIndex = pendingDropRow + 1
        } else {
            insertIndex = pendingDropRow
        }
        insertIndex = min(max(insertIndex, 0), items.count)
        
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
        tableView?.setDropRow(-1, dropOperation: .on)
    }
}

// MARK: - Views

private final class FavoriteSidebarCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let background = NSBox()
    private var iconLeadingConstraint: NSLayoutConstraint?
    private var iconCenterConstraint: NSLayoutConstraint?
    private var titleLeadingConstraint: NSLayoutConstraint?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
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
        
        iconLeadingConstraint = iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        iconCenterConstraint = iconView.centerXAnchor.constraint(equalTo: centerXAnchor)
        titleLeadingConstraint = titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
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
        titleField.textColor = isSelected ? .controlAccentColor : .labelColor
        
        iconLeadingConstraint?.isActive = showsTitle
        iconCenterConstraint?.isActive = !showsTitle
        titleLeadingConstraint?.isActive = showsTitle
        
        background.fillColor = isSelected
            ? NSColor.unemphasizedSelectedContentBackgroundColor
            : .clear
    }
}

private final class FavoriteSidebarRowView: NSTableRowView {
    weak var controller: FavoritesSidebarController?
    var rowIndex = -1
    var isFavoriteSelected = false
    
    private var mouseDownLocation: NSPoint = .zero
    private let dragThreshold: CGFloat = 4
    private var didBeginDrag = false
    
    override func drawSelection(in dirtyRect: NSRect) {
        // 选中样式由 cell 自己绘制。
    }
    
    private func selectRowIfNeeded() {
        guard let controller, rowIndex >= 0, let item = controller.item(at: rowIndex) else { return }
        controller.selectPath(item.path)
        controller.tableView?.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
    }
    
    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        didBeginDrag = false
        selectRowIfNeeded()
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
    
    override var intrinsicContentSize: NSSize {
        let rowCount = max(numberOfRows, 0)
        guard rowCount > 0 else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }
        let height = CGFloat(rowCount) * rowHeight + CGFloat(max(rowCount - 1, 0)) * intercellSpacing.height
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }
    
    private var isInstalled = false
    
    func installIfNeeded(showsTitle: Bool) {
        guard !isInstalled else {
            rowHeight = showsTitle ? 30 : 28
            return
        }
        isInstalled = true
        install(showsTitle: showsTitle)
    }
    
    private func install(showsTitle: Bool) {
        headerView = nil
        backgroundColor = .clear
        focusRingType = .none
        selectionHighlightStyle = .none
        columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        allowsEmptySelection = true
        allowsMultipleSelection = false
        usesAlternatingRowBackgroundColors = false
        intercellSpacing = NSSize(width: 0, height: 2)
        rowHeight = showsTitle ? 30 : 28
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FavoriteColumn"))
        column.width = 240
        addTableColumn(column)
        
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
    var onDropURLs: ([URL], String, Bool) -> Void
    
    func makeCoordinator() -> FavoritesSidebarController {
        FavoritesSidebarController(parent: self)
    }
    
    func makeNSView(context: Context) -> FavoritesTableView {
        let tableView = FavoritesTableView()
        tableView.installIfNeeded(showsTitle: showsTitle)
        tableView.controller = context.coordinator
        context.coordinator.tableView = tableView
        context.coordinator.parent = self
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.reloadData()
        return tableView
    }
    
    func updateNSView(_ tableView: FavoritesTableView, context: Context) {
        context.coordinator.parent = self
        tableView.installIfNeeded(showsTitle: showsTitle)
        context.coordinator.syncFromParent()
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
