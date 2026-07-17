import AppKit
import Foundation
import ObjectiveC

// MARK: - Icon preview (list view)

extension FileListTableController {
    static let listIconPreviewCellSize: CGFloat = 32
    static let listIconDisplaySize: CGFloat = 18
    private static let visibleIconPreviewBatchSize = 8

    static func parentDirectoryNameCellIcon(for cell: NSView?) -> NSImage {
        let scale = cell?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        return FileListThumbnailMetrics.parentDirectoryIcon(
            displaySide: listIconDisplaySize,
            scale: scale
        )
    }

    func configureNameCellIcon(in cell: NSTableCellView, item: FileListRow) {
        if item.isParentDirectoryEntry {
            FileListTableNameCellIconState.clear(on: cell)
            cell.imageView?.image = Self.parentDirectoryNameCellIcon(for: cell)
            return
        }

        guard useIconPreview else {
            FileListTableNameCellIconState.clear(on: cell)
            cell.imageView?.image = FileListWorkspaceIconCache.icon(forPath: item.iconPath)
            return
        }

        FileListTableNameCellIconState.prepare(for: item.id, on: cell)

        let cellSize = Self.listIconPreviewCellSize
        let screenScale = cell.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2

        if let cached = thumbnailGenerator.memoryCachedImage(for: item, cellSize: cellSize) {
            cell.imageView?.image = Self.listDisplayImage(from: cached)
            if cached.isThumbnail {
                FileListTableNameCellIconState.markLoaded(on: cell)
                return
            }
        } else {
            let placeholder = thumbnailGenerator.instantPlaceholder(
                for: item,
                cellSize: Self.listIconDisplaySize,
                screenScale: screenScale
            )
            cell.imageView?.image = Self.sizedListIcon(placeholder)
        }
    }

    func invalidatePendingIconPreviewLoads() {
        iconPreviewLoadGeneration &+= 1
        visibleIconPreviewLoadWorkItem?.cancel()
        visibleIconPreviewLoadWorkItem = nil
    }

    func scheduleVisibleIconPreviewLoad() {
        guard useIconPreview else { return }
        iconPreviewLoadGeneration &+= 1
        let generation = iconPreviewLoadGeneration
        visibleIconPreviewLoadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, generation == self.iconPreviewLoadGeneration else { return }
            self.loadVisibleIconPreviews(generation: generation)
        }
        visibleIconPreviewLoadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func loadVisibleIconPreviews(generation: Int) {
        guard generation == iconPreviewLoadGeneration else { return }
        guard useIconPreview, let tableView else { return }
        guard let nameColumnIndex = tableView.tableColumns.firstIndex(where: {
            FileListColumnID.from(column: $0) == .name
        }) else { return }

        let visible = tableView.rows(in: tableView.visibleRect)
        guard visible.length > 0 else { return }

        let tableRowCount = tableView.numberOfRows
        var rows: [(Int, FileListRow)] = []
        rows.reserveCapacity(visible.length)
        for row in visible.location..<(visible.location + visible.length) {
            guard row >= 0, row < displayRows.count, row < tableRowCount else { continue }
            let item = displayRows[row]
            guard !item.isParentDirectoryEntry else { continue }
            rows.append((row, item))
        }
        loadIconPreviewBatch(
            rows: rows,
            nameColumnIndex: nameColumnIndex,
            startIndex: 0,
            generation: generation
        )
    }

    private func loadIconPreviewBatch(
        rows: [(Int, FileListRow)],
        nameColumnIndex: Int,
        startIndex: Int,
        generation: Int
    ) {
        guard generation == iconPreviewLoadGeneration else { return }
        guard useIconPreview, let tableView else { return }
        guard nameColumnIndex >= 0, nameColumnIndex < tableView.numberOfColumns else { return }

        let end = min(startIndex + Self.visibleIconPreviewBatchSize, rows.count)
        let cellSize = Self.listIconPreviewCellSize
        let screenScale = tableView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let tableRowCount = tableView.numberOfRows

        for index in startIndex..<end {
            let (row, item) = rows[index]
            // 「在 Finder 显示」等外部导航会在分批间隙 reload；越界 row 会让 AppKit 抛异常崩溃。
            guard row >= 0, row < tableRowCount, row < displayRows.count else { continue }
            guard displayRows[row].id == item.id else { continue }
            guard let cell = tableView.view(
                atColumn: nameColumnIndex,
                row: row,
                makeIfNecessary: false
            ) as? NSTableCellView else { continue }
            guard FileListTableNameCellIconState.representedRowID(in: cell) == item.id else { continue }
            guard !FileListTableNameCellIconState.hasLoadedPreview(in: cell) else { continue }

            let token = FileListTableNameCellIconState.beginLoad(on: cell)
            thumbnailGenerator.load(
                for: item,
                cellSize: cellSize,
                screenScale: screenScale
            ) { [weak self, weak cell] delivery in
                guard let self, let cell else { return }
                guard self.useIconPreview else { return }
                guard FileListTableNameCellIconState.loadToken(in: cell) == token else { return }
                guard FileListTableNameCellIconState.representedRowID(in: cell) == item.id else { return }

                switch delivery {
                case .thumbnail(let image):
                    cell.imageView?.image = Self.sizedListIcon(image)
                    FileListTableNameCellIconState.markLoaded(on: cell)
                case .icon(let image):
                    cell.imageView?.image = FileListThumbnailMetrics.scaledIcon(
                        image,
                        cellSize: Self.listIconDisplaySize
                    )
                    FileListTableNameCellIconState.markLoaded(on: cell)
                }
            }
        }

        guard end < rows.count else { return }
        DispatchQueue.main.async { [weak self] in
            self?.loadIconPreviewBatch(
                rows: rows,
                nameColumnIndex: nameColumnIndex,
                startIndex: end,
                generation: generation
            )
        }
    }

    private static func listDisplayImage(from entry: ThumbnailCache.Entry) -> NSImage {
        if entry.isThumbnail {
            return sizedListIcon(entry.image)
        }
        return FileListThumbnailMetrics.scaledIcon(entry.image, cellSize: listIconDisplaySize)
    }

    private static func sizedListIcon(_ image: NSImage) -> NSImage {
        guard let copy = image.copy() as? NSImage else { return image }
        copy.size = NSSize(width: listIconDisplaySize, height: listIconDisplaySize)
        return copy
    }
}

// MARK: - Per-cell load state

private enum FileListTableNameCellIconState {
    private static var rowIDKey: UInt8 = 0
    private static var loadTokenKey: UInt8 = 0
    private static var loadedKey: UInt8 = 0

    static func representedRowID(in cell: NSTableCellView) -> String? {
        objc_getAssociatedObject(cell, &rowIDKey) as? String
    }

    static func loadToken(in cell: NSTableCellView) -> UUID? {
        objc_getAssociatedObject(cell, &loadTokenKey) as? UUID
    }

    static func hasLoadedPreview(in cell: NSTableCellView) -> Bool {
        (objc_getAssociatedObject(cell, &loadedKey) as? Bool) == true
    }

    static func prepare(for rowID: String, on cell: NSTableCellView) {
        if representedRowID(in: cell) != rowID {
            objc_setAssociatedObject(cell, &loadedKey, false, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        objc_setAssociatedObject(cell, &rowIDKey, rowID, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }

    static func beginLoad(on cell: NSTableCellView) -> UUID {
        let token = UUID()
        objc_setAssociatedObject(cell, &loadTokenKey, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return token
    }

    static func markLoaded(on cell: NSTableCellView) {
        objc_setAssociatedObject(cell, &loadedKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func clear(on cell: NSTableCellView) {
        objc_setAssociatedObject(cell, &rowIDKey, nil, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        objc_setAssociatedObject(cell, &loadTokenKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(cell, &loadedKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
