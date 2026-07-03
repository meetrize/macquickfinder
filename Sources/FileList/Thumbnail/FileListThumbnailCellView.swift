import AppKit

/// 单个缩略图格子的绘制视图（图标/缩略图 + 底部文件名与大小 + 文件夹图标居中数量）。
final class FileListThumbnailCellView: NSView {
    private enum ImagePresentation {
        case icon
        case thumbnail
    }
    
    private let imageContainer = NSView()
    private let imageView = NSImageView()
    private let bottomOverlay = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private let selectionOverlay = NSView()
    private let renameField = FileListInlineRenameField(frame: .zero)
    
    private var isCellSelected = false
    private var isDropTarget = false
    private var isHoverHighlighted = false
    private var rowHoverHighlightEnabled = false
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
        
        sizeLabel.font = .systemFont(ofSize: 10)
        sizeLabel.alignment = .right
        sizeLabel.isEditable = false
        sizeLabel.isSelectable = false
        sizeLabel.isBordered = false
        sizeLabel.drawsBackground = false
        bottomOverlay.addSubview(sizeLabel)
        
        countLabel.font = .systemFont(ofSize: FileListThumbnailMetrics.folderCountFontSize, weight: .bold)
        countLabel.alignment = .center
        countLabel.isEditable = false
        countLabel.isSelectable = false
        countLabel.isBordered = false
        countLabel.drawsBackground = false
        imageContainer.addSubview(countLabel)
        
        renameField.isHidden = true
        renameField.font = .systemFont(ofSize: 11)
        bottomOverlay.addSubview(renameField)
        
        updateAppearanceForCurrentTheme()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        if !renameField.isHidden {
            let pointInRename = renameField.convert(point, from: self)
            if renameField.bounds.contains(pointInRename) {
                return renameField
            }
        }
        // 鼠标事件交给 NSCollectionView 统一处理（与列表模式一致）；拖放命中仍由 collectionView 坐标解析。
        return nil
    }
    
    private var tooltipTrackingArea: NSTrackingArea?
    private var hoverTooltipText: String = ""
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tooltipTrackingArea {
            removeTrackingArea(tooltipTrackingArea)
            self.tooltipTrackingArea = nil
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tooltipTrackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard event.trackingArea === tooltipTrackingArea else { return }
        if rowHoverHighlightEnabled, !isCellSelected, !isDropTarget {
            isHoverHighlighted = true
            updateAppearanceForCurrentTheme()
        }
        guard !hoverTooltipText.isEmpty else { return }
        RailTooltipPresenter.show(text: hoverTooltipText, anchor: self)
    }

    override func mouseExited(with event: NSEvent) {
        guard event.trackingArea === tooltipTrackingArea else { return }
        if isHoverHighlighted {
            isHoverHighlighted = false
            updateAppearanceForCurrentTheme()
        }
        RailTooltipPresenter.hide()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let collectionView = enclosingThumbnailCollectionView else {
            super.rightMouseDown(with: event)
            return
        }
        collectionView.rightMouseDown(with: event)
    }
    
    func isPointInFileNameLabel(_ pointInWindow: NSPoint) -> Bool {
        let pointInCell = convert(pointInWindow, from: nil)
        let pointInLabel = nameLabel.convert(pointInCell, from: self)
        return nameLabel.bounds.contains(pointInLabel)
    }
    
    func isPointInFileNameOverlay(_ pointInWindow: NSPoint) -> Bool {
        let pointInCell = convert(pointInWindow, from: nil)
        return bottomOverlay.frame.contains(pointInCell)
    }
    
    private var enclosingThumbnailCollectionView: FileListThumbnailCollectionView? {
        var current: NSView? = superview
        while let view = current {
            if let collectionView = view as? FileListThumbnailCollectionView {
                return collectionView
            }
            current = view.superview
        }
        return nil
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
        
        let horizontalPadding: CGFloat = 4
        let labelSpacing: CGFloat = 4
        let labelY = FileListThumbnailMetrics.overlayLabelVerticalInset
        let sizeLabelY = labelY - FileListThumbnailMetrics.overlaySizeLabelExtraDownshift
        sizeLabel.sizeToFit()
        let sizeWidth = sizeLabel.isHidden ? 0 : ceil(sizeLabel.bounds.width)
        let nameWidth = max(
            0,
            bounds.width - horizontalPadding * 2 - sizeWidth - (sizeLabel.isHidden ? 0 : labelSpacing)
        )
        nameLabel.frame = NSRect(
            x: horizontalPadding,
            y: labelY,
            width: nameWidth,
            height: overlayHeight - 4
        )
        sizeLabel.frame = NSRect(
            x: bounds.width - horizontalPadding - sizeWidth,
            y: sizeLabelY,
            width: sizeWidth,
            height: overlayHeight - 4
        )
        renameField.frame = NSRect(
            x: horizontalPadding,
            y: labelY,
            width: bounds.width - horizontalPadding * 2,
            height: overlayHeight - 4
        )
        
        layoutFolderCountLabel()
    }
    
    private func layoutFolderCountLabel() {
        guard !countLabel.isHidden,
              imagePresentation == .icon,
              representedRow?.isDirectory == true
        else {
            countLabel.frame = .zero
            return
        }
        
        countLabel.sizeToFit()
        let iconFrame = imageView.frame
        let centerY = iconFrame.midY - FileListThumbnailMetrics.folderCountDownshift
        countLabel.frame = NSRect(
            x: iconFrame.midX - countLabel.bounds.width / 2,
            y: centerY - countLabel.bounds.height / 2,
            width: countLabel.bounds.width,
            height: countLabel.bounds.height
        )
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
        
        applyThumbnailSizeLabel(for: row)
        
        applyFolderItemCountLabel(for: row)
        
        hoverTooltipText = thumbnailToolTip(for: row)
        toolTip = nil
        syncSelectionOverlayVisibility()
        updateAppearanceForCurrentTheme()
        needsLayout = true
    }
    
    func setRowHoverHighlightEnabled(_ enabled: Bool) {
        guard rowHoverHighlightEnabled != enabled else { return }
        rowHoverHighlightEnabled = enabled
        if !enabled, isHoverHighlighted {
            isHoverHighlighted = false
        }
        updateAppearanceForCurrentTheme()
    }

    func updateSelection(_ isSelected: Bool, highlightText: String, row: FileListRow) {
        representedRow = row
        isCellSelected = isSelected
        if isSelected {
            isHoverHighlighted = false
        }
        guard renameField.isHidden else { return }
        nameLabel.attributedStringValue = FileListTextHighlight.attributedOverlayName(
            row.name,
            searchText: highlightText,
            isDirectory: row.isDirectory,
            isHidden: row.isHidden
        )
        applyFolderItemCountLabel(for: row)
        syncSelectionOverlayVisibility()
        updateAppearanceForCurrentTheme()
        needsLayout = true
    }
    
    func updateRowMetadata(_ row: FileListRow) {
        representedRow = row
        
        applyThumbnailSizeLabel(for: row)
        
        applyFolderItemCountLabel(for: row)
        
        hoverTooltipText = thumbnailToolTip(for: row)
        toolTip = nil
        updateAppearanceForCurrentTheme()
        needsLayout = true
    }
    
    func setDropTargetHighlighted(_ highlighted: Bool) {
        isDropTarget = highlighted
        if highlighted {
            isHoverHighlighted = false
        }
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
        renameField.textColor = .labelColor
        renameField.backgroundColor = .textBackgroundColor
        renameField.isHidden = false
        nameLabel.isHidden = true
        renameField.updateLayoutWidth(maxAvailableWidth: bounds.width - 8)
        window?.makeFirstResponder(renameField)
        if let editor = renameField.currentEditor() as? NSTextView {
            editor.textColor = .labelColor
            editor.insertionPointColor = .labelColor
        }
    }
    
    func endRename() {
        renameField.suppressEndEditingCommit = true
        if let collectionView = enclosingThumbnailCollectionView {
            window?.makeFirstResponder(collectionView)
        }
        renameField.isHidden = true
        nameLabel.isHidden = false
        renameField.onCommit = nil
        renameField.onCancel = nil
    }

    func activeRenameFieldValue() -> String? {
        guard !renameField.isHidden else { return nil }
        return renameField.stringValue
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
            self.needsLayout = true
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
        if let countText = folderItemCountText(for: row) {
            lines.append("项目：\(countText)")
        }
        if !row.dateDisplay.isEmpty {
            lines.append("修改：\(row.dateDisplay)")
        }
        lines.append("路径：\(row.id)")
        return lines.joined(separator: "\n")
    }
    
    private func folderItemCountText(for row: FileListRow) -> String? {
        guard row.isDirectory,
              !row.isParentDirectoryEntry,
              !FileListApplicationBundle.isBundle(path: row.iconPath),
              let countText = row.childCountDisplay,
              !countText.isEmpty
        else { return nil }
        return countText
    }
    
    private func applyFolderItemCountLabel(for row: FileListRow) {
        if let countText = folderItemCountText(for: row) {
            countLabel.isHidden = false
            countLabel.stringValue = countText
        } else {
            countLabel.isHidden = true
        }
    }
    
    private func applyThumbnailSizeLabel(for row: FileListRow) {
        let sizeText = thumbnailCompactSizeText(for: row)
        if sizeText.isEmpty {
            sizeLabel.isHidden = true
            sizeLabel.stringValue = ""
        } else {
            sizeLabel.isHidden = false
            sizeLabel.stringValue = sizeText
        }
    }
    
    private func thumbnailCompactSizeText(for row: FileListRow) -> String {
        guard !row.isParentDirectoryEntry else { return "" }
        let rawDisplay = row.sizeDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawDisplay.isEmpty, rawDisplay != "--" else { return "" }
        let prefix = rawDisplay.hasPrefix("≥") ? "≥" : ""
        return prefix + FileListThumbnailMetrics.compactSizeDisplay(bytes: row.size)
    }
    
    private func syncSelectionOverlayVisibility() {
        selectionOverlay.isHidden = !isCellSelected && !isHoverHighlighted && !isDropTarget
    }
    
    private func updateAppearanceForCurrentTheme() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let overlayBackground = NSColor(white: 0.88, alpha: 0.8)
        let sizeTextColor = NSColor(white: 0.35, alpha: 1)
        
        if let tint = representedRow.flatMap({ FileListThumbnailTypeTint.backgroundColor(for: $0, isDark: isDark) }) {
            imageContainer.layer?.backgroundColor = tint.cgColor
        } else {
            imageContainer.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        bottomOverlay.layer?.backgroundColor = overlayBackground.cgColor
        sizeLabel.textColor = sizeTextColor
        
        countLabel.textColor = NSColor.white.withAlphaComponent(FileListThumbnailMetrics.folderCountTextAlpha)
        countLabel.shadow = nil
        
        if isCellSelected {
            selectionOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            layer?.borderWidth = FileListThumbnailMetrics.selectionBorderWidth
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else if isDropTarget {
            selectionOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            layer?.borderWidth = FileListThumbnailMetrics.selectionBorderWidth
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor
        } else if isHoverHighlighted, rowHoverHighlightEnabled {
            selectionOverlay.layer?.backgroundColor = FileListRowHoverStyle.fillColor(for: effectiveAppearance).cgColor
            layer?.borderWidth = 0
            layer?.borderColor = nil
        } else {
            selectionOverlay.layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            layer?.borderColor = nil
        }
        syncSelectionOverlayVisibility()
    }
}
