import AppKit
import Foundation

/// 缩略图 Markdown 预览排版常量（一期）。
enum MarkdownThumbnailLayoutMetrics {
    /// 底部文件名条高度，与 `FileListThumbnailMetrics.labelOverlayHeight` 对齐。
    static let labelOverlayHeight = FileListThumbnailMetrics.labelOverlayHeight

    /// 标题区占「文件名条以上可视区」高度的比例（约上半部的一半）。
    static let titleZoneHeightRatio: CGFloat = 0.32

    /// 顶部留白，避免标题 ascender 被裁切。
    static func contentTopInset(for cellSize: CGFloat) -> CGFloat {
        max(4, cellSize * 0.04)
    }

    /// 标题与正文之间的间距。
    static func sectionGap(for cellSize: CGFloat) -> CGFloat {
        max(2, cellSize * 0.02)
    }

    /// 水平内边距。
    static func horizontalPadding(for cellSize: CGFloat) -> CGFloat {
        max(4, cellSize * 0.06)
    }

    /// 标题基础字号：H1 基准，每深一级减小。
    static func titleFontSize(cellSize: CGFloat, headingLevel: Int?) -> CGFloat {
        let level = CGFloat(headingLevel ?? 2)
        let base = cellSize * 0.18
        let adjusted = base - (level - 1) * cellSize * 0.014
        return min(max(10, adjusted), cellSize * 0.26)
    }

    /// 无 ATX 标题时 fallback 标题略小。
    static func fallbackTitleFontSize(cellSize: CGFloat) -> CGFloat {
        min(max(9, cellSize * 0.13), cellSize * 0.18)
    }

    static func bodyFontSize(for cellSize: CGFloat) -> CGFloat {
        max(8, cellSize * 0.09)
    }

    static func drawableHeight(cellSize: CGFloat) -> CGFloat {
        max(1, cellSize - labelOverlayHeight - contentTopInset(for: cellSize))
    }

    static func titleZoneHeight(cellSize: CGFloat) -> CGFloat {
        drawableHeight(cellSize: cellSize) * titleZoneHeightRatio
    }

    static func bodyZoneHeight(cellSize: CGFloat) -> CGFloat {
        let drawable = drawableHeight(cellSize: cellSize)
        return max(1, drawable - titleZoneHeight(cellSize: cellSize) - sectionGap(for: cellSize))
    }
}

/// 为 `.md` / `.markdown` 生成标题 + 正文摘要缩略图。
enum MarkdownPreviewThumbnailRenderer {
    static func render(
        for url: URL,
        cellSize: CGFloat,
        screenScale: CGFloat
    ) -> NSImage? {
        guard
            let text = MarkdownThumbnailSnippetExtractor.readPreviewText(from: url),
            let snippet = MarkdownThumbnailSnippetExtractor.extract(from: text),
            !snippet.titleText.isEmpty || !snippet.bodyPreview.isEmpty
        else { return nil }

        let scale = max(1, screenScale)
        let pixelSize = max(1, (cellSize * scale).rounded(.toNearestOrAwayFromZero))
        let pixelCount = Int(pixelSize)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelCount,
            pixelsHigh: pixelCount,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        rep.size = NSSize(width: cellSize, height: cellSize)

        let padding = MarkdownThumbnailLayoutMetrics.horizontalPadding(for: cellSize)
        let contentWidth = max(1, cellSize - padding * 2)
        let topInset = MarkdownThumbnailLayoutMetrics.contentTopInset(for: cellSize)
        let titleZoneHeight = MarkdownThumbnailLayoutMetrics.titleZoneHeight(cellSize: cellSize)
        let bodyZoneHeight = MarkdownThumbnailLayoutMetrics.bodyZoneHeight(cellSize: cellSize)
        let sectionGap = MarkdownThumbnailLayoutMetrics.sectionGap(for: cellSize)

        let titleFont = resolvedTitleFont(
            snippet: snippet,
            cellSize: cellSize,
            width: contentWidth,
            maxHeight: titleZoneHeight - titleVerticalPadding(for: cellSize)
        )
        let bodyFont = NSFont.systemFont(
            ofSize: MarkdownThumbnailLayoutMetrics.bodyFontSize(for: cellSize),
            weight: .regular
        )

        let titleString = snippet.titleText as NSString
        let bodyString = snippet.bodyPreview as NSString

        let titleRect = CGRect(
            x: padding,
            y: labelOverlayTopY(cellSize: cellSize) + bodyZoneHeight + sectionGap,
            width: contentWidth,
            height: titleZoneHeight
        ).insetBy(dx: 0, dy: titleVerticalPadding(for: cellSize) / 2)
        let bodyRect = CGRect(
            x: padding,
            y: labelOverlayTopY(cellSize: cellSize),
            width: contentWidth,
            height: bodyZoneHeight
        ).insetBy(dx: 0, dy: 1)

        let lightAppearance = NSAppearance(named: .aqua)
        lightAppearance?.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

            NSColor.clear.setFill()
            NSRect(x: 0, y: 0, width: cellSize, height: cellSize).fill()

            if titleString.length > 0 {
                drawText(
                    titleString,
                    in: titleRect,
                    attributes: titleAttributes(font: titleFont),
                    maxLines: 2,
                    alignment: .natural
                )
            }
            if bodyString.length > 0 {
                drawText(
                    bodyString,
                    in: bodyRect,
                    attributes: bodyAttributes(font: bodyFont),
                    maxLines: 3,
                    alignment: .natural
                )
            }

            NSGraphicsContext.restoreGraphicsState()
        }

        let image = NSImage(size: NSSize(width: cellSize, height: cellSize))
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Private

    private static func labelOverlayTopY(cellSize: CGFloat) -> CGFloat {
        MarkdownThumbnailLayoutMetrics.labelOverlayHeight
    }

    private static func titleVerticalPadding(for cellSize: CGFloat) -> CGFloat {
        max(2, cellSize * 0.02)
    }

    private static func resolvedTitleFont(
        snippet: MarkdownThumbnailSnippet,
        cellSize: CGFloat,
        width: CGFloat,
        maxHeight: CGFloat
    ) -> NSFont {
        let baseSize: CGFloat
        if snippet.isFallbackTitle {
            baseSize = MarkdownThumbnailLayoutMetrics.fallbackTitleFontSize(cellSize: cellSize)
        } else {
            baseSize = MarkdownThumbnailLayoutMetrics.titleFontSize(
                cellSize: cellSize,
                headingLevel: snippet.headingLevel
            )
        }

        var size = baseSize
        let minSize: CGFloat = 9
        let title = snippet.titleText as NSString
        while size >= minSize {
            let font = NSFont.systemFont(ofSize: size, weight: .semibold)
            let height = measuredTextHeight(
                title,
                width: width,
                attributes: titleAttributes(font: font),
                maxLines: 2
            )
            if height <= maxHeight {
                return font
            }
            size -= 1
        }
        return NSFont.systemFont(ofSize: minSize, weight: .semibold)
    }

    private static func titleAttributes(font: NSFont) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.lineSpacing = 1
        return [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1),
            .paragraphStyle: style,
        ]
    }

    private static func bodyAttributes(font: NSFont) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        style.lineSpacing = 1
        style.maximumLineHeight = font.pointSize * 1.15
        style.minimumLineHeight = font.pointSize * 1.15
        return [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1),
            .paragraphStyle: style,
        ]
    }

    private static func measuredTextHeight(
        _ text: NSString,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any],
        maxLines: Int
    ) -> CGFloat {
        let rect = text.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let lineHeight = (attributes[.font] as? NSFont)?.pointSize ?? 12
        let maxHeight = lineHeight * 1.15 * CGFloat(maxLines) + CGFloat(max(0, maxLines - 1))
        return min(ceil(rect.height), maxHeight)
    }

    private static func drawText(
        _ text: NSString,
        in rect: CGRect,
        attributes: [NSAttributedString.Key: Any],
        maxLines: Int,
        alignment: NSTextAlignment
    ) {
        let style = ((attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        style.alignment = alignment
        var attrs = attributes
        attrs[.paragraphStyle] = style

        let storage = NSMutableAttributedString(string: text as String, attributes: attrs)
        let textContainer = NSTextContainer(size: NSSize(width: rect.width, height: rect.height))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = maxLines
        textContainer.lineBreakMode = style.lineBreakMode

        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        let textStorage = NSTextStorage(attributedString: storage)
        textStorage.addLayoutManager(layoutManager)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }

        NSGraphicsContext.saveGraphicsState()
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: rect.origin)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: rect.origin)
        NSGraphicsContext.restoreGraphicsState()
    }
}
