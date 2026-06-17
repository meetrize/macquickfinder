import AppKit

/// 单个缩略图格子的绘制视图（图标/缩略图 + 底部文件名 + 右上角大小）。
final class FileListThumbnailCellView: NSView {
    private enum ImagePresentation {
        case icon
        case thumbnail
    }
    
    private let imageContainer = NSView()
    private let imageView = NSImageView()
    private let bottomOverlay = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let sizeBadge = NSView()
    private let sizeLabel = NSTextField(labelWithString: "")
    private let countBadge = NSView()
    private let countLabel = NSTextField(labelWithString: "")
    private let selectionOverlay = NSView()
    private let renameField = FileListInlineRenameField(frame: .zero)
    
    private var isCellSelected = false
    private var isDropTarget = false
    private var imagePresentation: ImagePresentation = .icon
    private var representedRow: FileListRow?
    private var configuredCellSize: CGFloat = FileListThumbnailMetrics.defaultCellSize
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = FileListThumbnailMetrics.cellCornerRadius
        layer?.masksToBounds = true
        
        imageContainer.wantsLayer = true
        imageContainer.layer?.masksToBounds = true
        addSubview(imageContainer)
        
        imageView.imageAlignment = .alignCenter
        imageContainer.addSubview(imageView)
        
        selectionOverlay.wantsLayer = true
        selectionOverlay.isHidden = true
        addSubview(selectionOverlay)
        
        bottomOverlay.wantsLayer = true
        addSubview(bottomOverlay)
        
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.cell?.truncatesLastVisibleLine = true
        bottomOverlay.addSubview(nameLabel)
        
        sizeBadge.wantsLayer = true
        sizeBadge.layer?.cornerRadius = FileListThumbnailMetrics.sizeBadgeCornerRadius
        addSubview(sizeBadge)
        
        sizeLabel.font = .systemFont(ofSize: 9)
        sizeLabel.alignment = .right
        sizeLabel.isEditable = false
        sizeLabel.isSelectable = false
        sizeLabel.isBordered = false
        sizeLabel.drawsBackground = false
        sizeBadge.addSubview(sizeLabel)
        
        countBadge.wantsLayer = true
        countBadge.layer?.cornerRadius = FileListThumbnailMetrics.sizeBadgeCornerRadius
        addSubview(countBadge)
        
        countLabel.font = .systemFont(ofSize: 9, weight: .medium)
        countLabel.alignment = .center
        countLabel.isEditable = false
        countLabel.isSelectable = false
        countLabel.isBordered = false
        countLabel.drawsBackground = false
        countBadge.addSubview(countLabel)
        
        renameField.isHidden = true
        renameField.font = .systemFont(ofSize: 11)
        renameField.textColor = .white
        renameField.backgroundColor = NSColor.black.withAlphaComponent(0.65)
        bottomOverlay.addSubview(renameField)
        
        updateAppearanceForCurrentTheme()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        guard renameField.isHidden else { return hit }
        if hit === nameLabel || hit?.isDescendant(of: bottomOverlay) == true {
            return self
        }
        return hit
    }
    
    override func mouseDown(with event: NSEvent) {
        forwardMouseEvent(event) { collectionView, indexPath in
            collectionView.handleItemMouseDown(event, indexPath: indexPath)
        } fallback: {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        forwardMouseEvent(event) { collectionView, _ in
            collectionView.handleItemMouseUp(event)
        } fallback: {
            super.mouseUp(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        forwardMouseEvent(event) { collectionView, _ in
            collectionView.handleItemMouseDragged(event)
        } fallback: {
            super.mouseDragged(with: event)
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let collectionView = enclosingThumbnailCollectionView else {
            super.rightMouseDown(with: event)
            return
        }
        collectionView.rightMouseDown(with: event)
    }
    
    func isPointInFileNameOverlay(_ pointInWindow: NSPoint) -> Bool {
        let pointInCell = convert(pointInWindow, from: nil)
        return bottomOverlay.frame.contains(pointInCell)
    }
    
    private var enclosingThumbnailCollectionView: FileListThumbnailCollectionView? {
        var current: NSView? = self
        while let view = current {
            if let collectionView = view as? FileListThumbnailCollectionView {
                return collectionView
            }
            current = view.superview
        }
        return nil
    }
    
    private func forwardMouseEvent(
        _ event: NSEvent,
        handler: (FileListThumbnailCollectionView, IndexPath) -> Void,
        fallback: () -> Void
    ) {
        guard let collectionView = enclosingThumbnailCollectionView else {
            fallback()
            return
        }
        let point = collectionView.convert(event.locationInWindow, from: nil)
        guard let indexPath = collectionView.indexPathForItem(at: point) else {
            fallback()
            return
        }
        handler(collectionView, indexPath)
    }
    
    override func layout() {
        super.layout()
        let bounds = self.bounds
        imageContainer.frame = bounds
        updateImageViewFrame()
        selectionOverlay.frame = bounds
        
        let overlayHeight = FileListThumbnailMetrics.labelOverlayHeight
        bottomOverlay.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: overlayHeight
        )
        nameLabel.frame = NSRect(
            x: 4,
            y: 2,
            width: bounds.width - 8,
            height: overlayHeight - 4
        )
        renameField.frame = nameLabel.frame
        
        sizeLabel.sizeToFit()
        let badgeWidth = min(bounds.width - 8, sizeLabel.bounds.width + 8)
        let badgeHeight = sizeLabel.bounds.height + 4
        sizeBadge.frame = NSRect(
            x: bounds.width - badgeWidth - 4,
            y: bounds.height - badgeHeight - 4,
            width: badgeWidth,
            height: badgeHeight
        )
        sizeLabel.frame = NSRect(
            x: 4,
            y: 2,
            width: badgeWidth - 8,
            height: badgeHeight - 4
        )
        
        if countBadge.isHidden {
            countBadge.frame = .zero
        } else {
            countLabel.sizeToFit()
            let countBadgeWidth = min(bounds.width - 8, max(18, countLabel.bounds.width + 8))
            let countBadgeHeight = countLabel.bounds.height + 4
            countBadge.frame = NSRect(
                x: bounds.width - countBadgeWidth - 4,
                y: 4,
                width: countBadgeWidth,
                height: countBadgeHeight
            )
            countLabel.frame = NSRect(
                x: 4,
                y: 2,
                width: countBadgeWidth - 8,
                height: countBadgeHeight - 4
            )
        }
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearanceForCurrentTheme()
    }
    
    func configure(
        row: FileListRow,
        isSelected: Bool,
        highlightText: String,
        placeholderImage: NSImage,
        cellSize: CGFloat
    ) {
        representedRow = row
        configuredCellSize = cellSize
        isCellSelected = isSelected
        applyImage(placeholderImage, presentation: .icon, animated: false)
        
        nameLabel.attributedStringValue = FileListTextHighlight.attributedOverlayName(
            row.name,
            searchText: highlightText,
            isDirectory: row.isDirectory,
            isHidden: row.isHidden
        )
        
        let sizeText = row.sizeDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        if row.isParentDirectoryEntry || sizeText.isEmpty || sizeText == "--" {
            sizeBadge.isHidden = true
        } else {
            sizeBadge.isHidden = false
            sizeLabel.stringValue = sizeText
        }
        
        if let countText = row.childCountDisplay, !countText.isEmpty, row.isDirectory, !row.isParentDirectoryEntry {
            countBadge.isHidden = false
            countLabel.stringValue = countText
        } else {
            countBadge.isHidden = true
        }
        
        toolTip = thumbnailToolTip(for: row)
        selectionOverlay.isHidden = !isSelected
        updateAppearanceForCurrentTheme()
        needsLayout = true
    }
    
    func updateSelection(_ isSelected: Bool, highlightText: String, row: FileListRow) {
        representedRow = row
        isCellSelected = isSelected
        guard renameField.isHidden else { return }
        nameLabel.attributedStringValue = FileListTextHighlight.attributedOverlayName(
            row.name,
            searchText: highlightText,
            isDirectory: row.isDirectory,
            isHidden: row.isHidden
        )
        if let countText = row.childCountDisplay, !countText.isEmpty, row.isDirectory, !row.isParentDirectoryEntry {
            countBadge.isHidden = false
            countLabel.stringValue = countText
        } else {
            countBadge.isHidden = true
        }
        selectionOverlay.isHidden = !isSelected
        updateAppearanceForCurrentTheme()
        needsLayout = true
    }
    
    func updateRowMetadata(_ row: FileListRow) {
        representedRow = row
        
        let sizeText = row.sizeDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        if row.isParentDirectoryEntry || sizeText.isEmpty || sizeText == "--" {
            sizeBadge.isHidden = true
        } else {
            sizeBadge.isHidden = false
            sizeLabel.stringValue = sizeText
        }
        
        if let countText = row.childCountDisplay, !countText.isEmpty, row.isDirectory, !row.isParentDirectoryEntry {
            countBadge.isHidden = false
            countLabel.stringValue = countText
        } else {
            countBadge.isHidden = true
        }
        
        toolTip = thumbnailToolTip(for: row)
        updateAppearanceForCurrentTheme()
        needsLayout = true
    }
    
    func setDropTargetHighlighted(_ highlighted: Bool) {
        isDropTarget = highlighted
        updateAppearanceForCurrentTheme()
    }
    
    func beginRename(
        name: String,
        onCommit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        renameField.onCommit = onCommit
        renameField.onCancel = onCancel
        renameField.stringValue = name
        renameField.isHidden = false
        nameLabel.isHidden = true
        renameField.updateLayoutWidth(maxAvailableWidth: bounds.width - 8)
        window?.makeFirstResponder(renameField)
    }
    
    func endRename() {
        renameField.isHidden = true
        nameLabel.isHidden = false
        renameField.onCommit = nil
        renameField.onCancel = nil
    }
    
    func applyLoadedImage(_ image: NSImage, isThumbnail: Bool, animated: Bool) {
        applyImage(image, presentation: isThumbnail ? .thumbnail : .icon, animated: animated)
    }
    
    private func applyImage(_ image: NSImage, presentation: ImagePresentation, animated: Bool) {
        imagePresentation = presentation
        
        let updateBlock = { [weak self] in
            guard let self else { return }
            self.imageView.image = image
            switch presentation {
            case .icon:
                self.imageView.imageScaling = .scaleProportionallyUpOrDown
                self.imageView.wantsLayer = false
            case .thumbnail:
                self.imageView.imageScaling = .scaleProportionallyUpOrDown
                self.imageView.wantsLayer = false
            }
            self.updateImageViewFrame()
            self.imageView.alphaValue = 1
        }
        
        guard animated else {
            updateBlock()
            return
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.imageView.animator().alphaValue = 0.82
        } completionHandler: {
            updateBlock()
        }
    }
    
    private func updateImageViewFrame() {
        let containerBounds = imageContainer.bounds
        switch imagePresentation {
        case .icon:
            let frame = resolvedIconFrame(in: containerBounds)
            imageView.frame = frame
            if let image = imageView.image, frame.width > 1, frame.height > 1 {
                let side = min(frame.width, frame.height)
                if abs(image.size.width - side) > 0.5 || abs(image.size.height - side) > 0.5 {
                    imageView.image = FileListThumbnailMetrics.scaledIcon(image, cellSize: configuredCellSize)
                }
            }
        case .thumbnail:
            guard let image = imageView.image else {
                imageView.frame = containerBounds
                return
            }
            imageView.frame = FileListThumbnailMetrics.aspectFillFrame(
                imageSize: image.size,
                in: containerBounds.size
            )
        }
    }
    
    private func resolvedIconFrame(in bounds: NSRect) -> NSRect {
        if bounds.width > 1, bounds.height > 1 {
            return imageInsetFrame(in: bounds)
        }
        let side = FileListThumbnailMetrics.iconFittingSide(in: configuredCellSize)
        return NSRect(
            x: (configuredCellSize - side) / 2,
            y: (configuredCellSize - side) / 2,
            width: side,
            height: side
        )
    }
    
    private func imageInsetFrame(in bounds: NSRect) -> NSRect {
        let inset = bounds.width * FileListThumbnailMetrics.iconContentInsetRatio
        return bounds.insetBy(dx: inset, dy: inset)
    }
    
    private func thumbnailToolTip(for row: FileListRow) -> String {
        var lines: [String] = [row.name]
        if !row.fileType.isEmpty {
            lines.append("类型：\(row.fileType)")
        }
        let sizeText = row.sizeDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sizeText.isEmpty {
            lines.append("大小：\(sizeText)")
        }
        if let countText = row.childCountDisplay, !countText.isEmpty, row.isDirectory {
            lines.append("项目：\(countText)")
        }
        if !row.dateDisplay.isEmpty {
            lines.append("修改：\(row.dateDisplay)")
        }
        lines.append("路径：\(row.id)")
        return lines.joined(separator: "\n")
    }
    
    private func updateAppearanceForCurrentTheme() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let overlayBackground = NSColor.black.withAlphaComponent(isDark ? 0.55 : 0.45)
        let badgeBackground = NSColor.black.withAlphaComponent(isDark ? 0.5 : 0.4)
        let secondaryText = NSColor.white.withAlphaComponent(0.92)
        
        if let tint = representedRow.flatMap({ FileListThumbnailTypeTint.backgroundColor(for: $0, isDark: isDark) }) {
            imageContainer.layer?.backgroundColor = tint.cgColor
        } else {
            imageContainer.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        bottomOverlay.layer?.backgroundColor = overlayBackground.cgColor
        sizeBadge.layer?.backgroundColor = badgeBackground.cgColor
        countBadge.layer?.backgroundColor = badgeBackground.cgColor
        sizeLabel.textColor = secondaryText
        countLabel.textColor = secondaryText
        
        if isCellSelected {
            selectionOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            layer?.borderWidth = FileListThumbnailMetrics.selectionBorderWidth
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else if isDropTarget {
            selectionOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            layer?.borderWidth = FileListThumbnailMetrics.selectionBorderWidth
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor
        } else {
            selectionOverlay.layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            layer?.borderColor = nil
        }
    }
}
