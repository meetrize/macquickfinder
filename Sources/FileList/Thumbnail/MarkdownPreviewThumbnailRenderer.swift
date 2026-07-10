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
        max(3, cellSize * 0.03)
    }

    /// 标题与正文之间的间距。
    static func sectionGap(for cellSize: CGFloat) -> CGFloat {
        max(2, cellSize * 0.02)
    }

    /// 水平内边距。
    static func horizontalPadding(for cellSize: CGFloat) -> CGFloat {
        max(3, cellSize * 0.035)
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
                drawTitle(
                    titleString,
                    in: titleRect,
                    font: titleFont
                )
            }
            if bodyString.length > 0 {
                drawBody(
                    bodyString,
                    in: bodyRect,
                    font: bodyFont
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
            let attrs = titleAttributes(font: font)
            let singleLineWidth = ceil(title.size(withAttributes: attrs).width)
            if singleLineWidth <= width {
                return font
            }
            let height = measuredTextHeight(
                title,
                width: width,
                attributes: attrs,
                maxLines: 2
            )
            if height <= maxHeight {
                return font
            }
            size -= 1
        }
        return NSFont.systemFont(ofSize: minSize, weight: .semibold)
    }

    private static func drawTitle(_ text: NSString, in rect: CGRect, font: NSFont) {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byCharWrapping
        style.lineSpacing = 1
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1),
            .paragraphStyle: style,
        ]
        text.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
    }

    private static func drawBody(_ text: NSString, in rect: CGRect, font: NSFont) {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byTruncatingTail
        style.lineSpacing = 1
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1),
            .paragraphStyle: style,
        ]
        text.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
    }

    private static func titleAttributes(font: NSFont) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        style.lineSpacing = 1
        return [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1),
            .paragraphStyle: style,
        ]
    }

    private static func measuredTextHeight(
        _ text: NSString,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any],
        maxLines: Int
    ) -> CGFloat {
        let style = ((attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        var attrs = attributes
        attrs[.paragraphStyle] = style

        let rect = text.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let lineHeight = (attributes[.font] as? NSFont)?.pointSize ?? 12
        let maxHeight = lineHeight * 1.2 * CGFloat(maxLines) + CGFloat(max(0, maxLines - 1))
        return min(ceil(rect.height), maxHeight)
    }
}
