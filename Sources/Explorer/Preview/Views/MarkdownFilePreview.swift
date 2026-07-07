import SwiftUI
import AppKit

struct MarkdownFilePreview: NSViewRepresentable {
    let markdown: String
    let wrapLines: Bool
    var textContentInset: CGFloat = 0
    @Binding var zoomScale: CGFloat
    @Binding var previewTextSelectionActive: Bool
    @Binding var searchQuery: String
    @Binding var searchNextToken: UInt
    @Binding var searchPrevToken: UInt
    @Binding var searchMatchCount: Int
    @Binding var searchCurrentIndex: Int

    private static let tableSeparatorRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: "^\\s*\\|?\\s*:?-{2,}:?\\s*(\\|\\s*:?-{2,}:?\\s*)+\\|?\\s*$",
            options: []
        )
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(
            searchMatchCount: $searchMatchCount,
            searchCurrentIndex: $searchCurrentIndex
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        PreviewScrollerChrome.applyPanelSafeBounds(to: scrollView)
        scrollView.drawsBackground = false

        let textView = PreviewCodeTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.textContainer?.lineFragmentPadding = 0
        applyTextContainerInset(textContentInset, to: textView)
        PreviewTextWrapLayout.configure(textView: textView, scrollView: scrollView, wrapLines: wrapLines)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.previewTextSelectionActive = $previewTextSelectionActive
        textView.onInteractionStateChanged = { [weak coordinator = context.coordinator] in
            coordinator?.updatePreviewTextSelectionActive()
        }
        context.coordinator.installFocusTracking(for: textView)
        context.coordinator.currentScale = 1.0
        context.coordinator.lastMarkdown = markdown
        context.coordinator.lastZoomScale = zoomScale
        context.coordinator.textContentInset = textContentInset
        context.coordinator.scrollView = scrollView
        context.coordinator.relayoutMarkdown = { textView, scrollView in
            let layoutWidth = tableLayoutWidth(for: scrollView, scale: zoomScale)
            guard abs(layoutWidth - context.coordinator.lastTableLayoutWidth) > 0.5 else { return }
            context.coordinator.lastTableLayoutWidth = layoutWidth
            context.coordinator.lastZoomScale = zoomScale
            applyMarkdown(markdown, to: textView, layoutWidth: layoutWidth)
            applyScale(zoomScale, to: textView, context: context)
            context.coordinator.updateSearchIfNeeded(
                textView: textView,
                searchQuery: searchQuery,
                searchNextToken: searchNextToken,
                searchPrevToken: searchPrevToken
            )
        }
        context.coordinator.installTableLayoutWidthTracking()

        let layoutWidth = tableLayoutWidth(for: scrollView, scale: zoomScale)
        context.coordinator.lastTableLayoutWidth = layoutWidth
        applyMarkdown(markdown, to: textView, layoutWidth: layoutWidth)
        context.coordinator.wrapLayout.wrapLinesEnabled = wrapLines
        context.coordinator.wrapLayout.lastWrapLines = wrapLines
        context.coordinator.wrapLayout.lastTrackedContentWidth = PreviewTextWrapLayout.effectiveContentWidth(for: scrollView)
        PreviewTextWrapLayout.installContentWidthTracking(
            scrollView: scrollView,
            textView: textView,
            coordinator: context.coordinator.wrapLayout
        )
        PreviewTextWrapLayout.scheduleDeferredLayout(textView: textView, scrollView: scrollView, wrapLines: wrapLines)
        DispatchQueue.main.async {
            let deferredWidth = tableLayoutWidth(for: scrollView, scale: zoomScale)
            guard abs(deferredWidth - context.coordinator.lastTableLayoutWidth) > 0.5 else { return }
            context.coordinator.lastTableLayoutWidth = deferredWidth
            applyMarkdown(markdown, to: textView, layoutWidth: deferredWidth)
            applyScale(zoomScale, to: textView, context: context)
        }

        applyScale(zoomScale, to: textView, context: context)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        context.coordinator.textContentInset = textContentInset
        context.coordinator.scrollView = scrollView
        context.coordinator.relayoutMarkdown = { textView, scrollView in
            let layoutWidth = tableLayoutWidth(for: scrollView, scale: zoomScale)
            guard abs(layoutWidth - context.coordinator.lastTableLayoutWidth) > 0.5 else { return }
            context.coordinator.lastTableLayoutWidth = layoutWidth
            context.coordinator.lastZoomScale = zoomScale
            applyMarkdown(markdown, to: textView, layoutWidth: layoutWidth)
            applyScale(zoomScale, to: textView, context: context)
            context.coordinator.updateSearchIfNeeded(
                textView: textView,
                searchQuery: searchQuery,
                searchNextToken: searchNextToken,
                searchPrevToken: searchPrevToken
            )
        }

        context.coordinator.wrapLayout.wrapLinesEnabled = wrapLines
        PreviewTextWrapLayout.configure(textView: textView, scrollView: scrollView, wrapLines: wrapLines)

        applyScale(zoomScale, to: textView, context: context)
        let layoutWidth = tableLayoutWidth(for: scrollView, scale: zoomScale)
        let layoutWidthChanged = abs(layoutWidth - context.coordinator.lastTableLayoutWidth) > 0.5
        let wrapChanged = context.coordinator.wrapLayout.lastWrapLines != wrapLines
        let markdownChanged = context.coordinator.lastMarkdown != markdown
        let zoomChanged = abs(context.coordinator.lastZoomScale - zoomScale) > 0.0001

        if wrapChanged || markdownChanged || layoutWidthChanged || zoomChanged {
            if wrapChanged {
                context.coordinator.wrapLayout.lastWrapLines = wrapLines
            }
            context.coordinator.lastMarkdown = markdown
            context.coordinator.lastZoomScale = zoomScale
            context.coordinator.lastTableLayoutWidth = layoutWidth
            applyMarkdown(markdown, to: textView, layoutWidth: layoutWidth)
            if markdownChanged || wrapChanged {
                context.coordinator.searchCurrentIndex = 0
                context.coordinator.lastHighlightedSearchRanges = []
                textView.scrollToBeginningOfDocument(nil)
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            }
            PreviewTextWrapLayout.invalidateLayout(textView: textView)
        } else if wrapLines {
            let width = PreviewTextWrapLayout.effectiveContentWidth(for: scrollView)
            if abs(width - context.coordinator.wrapLayout.lastTrackedContentWidth) > 0.5 {
                context.coordinator.wrapLayout.lastTrackedContentWidth = width
                PreviewTextWrapLayout.invalidateLayout(textView: textView)
            }
        }

        applyTextContainerInset(textContentInset, to: textView)
        context.coordinator.updateSearchIfNeeded(
            textView: textView,
            searchQuery: searchQuery,
            searchNextToken: searchNextToken,
            searchPrevToken: searchPrevToken
        )
    }

    private func tableLayoutWidth(for scrollView: NSScrollView, scale: CGFloat) -> CGFloat {
        let contentWidth = PreviewTextWrapLayout.effectiveContentWidth(for: scrollView)
        let normalizedScale = max(scale, 0.5)
        let horizontalInsets = textContentInset * 2
        return max(contentWidth / normalizedScale - horizontalInsets, 160)
    }

    private func applyMarkdown(_ markdown: String, to textView: NSTextView, layoutWidth: CGFloat? = nil) {
        // 以原始文本作为预览基准，保证换行/缩进完全保留，再做轻量样式增强。
        let rendered = NSMutableAttributedString(string: markdown)

        let fullRange = NSRange(location: 0, length: rendered.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
        paragraphStyle.lineSpacing = 2
        rendered.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        rendered.addAttribute(
            .font,
            value: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            range: fullRange
        )

        // 低成本标题增强：仅识别 ATX 标题（# 到 ######），并在预览里隐藏前缀 # 号。
        var renderedString = rendered.string as NSString
        var fullRenderedRange = NSRange(location: 0, length: renderedString.length)
        let headingRegex = try? NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)$", options: [.anchorsMatchLines])
        if let headingRegex {
            let matches = headingRegex.matches(in: rendered.string, options: [], range: fullRenderedRange)
            for match in matches.reversed() {
                guard match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound else { continue }

                let level = max(1, min(6, match.range(at: 1).length))
                let markerRange = match.range(at: 1)
                let titleRange = match.range(at: 2) // 整个「1. 构建前端」都加粗加大
                let markerEnd = markerRange.location + markerRange.length
                let removeLength = max(0, titleRange.location - markerEnd)
                let removeRange = NSRange(location: markerRange.location, length: markerRange.length + removeLength)

                rendered.replaceCharacters(in: removeRange, with: "")

                let adjustedTitleRange = NSRange(
                    location: max(0, titleRange.location - removeRange.length),
                    length: titleRange.length
                )
                let size = max(13, 22 - CGFloat(level) * 2)
                let font = NSFont.systemFont(ofSize: size, weight: .semibold)
                rendered.addAttribute(.font, value: font, range: adjustedTitleRange)
            }
            renderedString = rendered.string as NSString
            fullRenderedRange = NSRange(location: 0, length: renderedString.length)
        }

        // 低成本列表缩进：支持 -, *, + 与有序列表（1. / 2. ...）。
        let bulletRegex = try? NSRegularExpression(pattern: "^([ \\t]*)([-*+])\\s+", options: [.anchorsMatchLines])
        bulletRegex?.enumerateMatches(in: rendered.string, options: [], range: fullRenderedRange) { match, _, _ in
            guard
                let match,
                match.numberOfRanges >= 2,
                match.range.location != NSNotFound
            else { return }
            let lineRange = renderedString.lineRange(for: match.range)
            let leadingWhitespaceCount = max(0, match.range(at: 1).length)
            let indentBase = CGFloat(leadingWhitespaceCount) * 6
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
            style.lineSpacing = 2
            style.firstLineHeadIndent = indentBase
            style.headIndent = indentBase + 16
            rendered.addAttribute(.paragraphStyle, value: style, range: lineRange)
        }

        let orderedListRegex = try? NSRegularExpression(pattern: "^([ \\t]*)(\\d+)\\.\\s+", options: [.anchorsMatchLines])
        orderedListRegex?.enumerateMatches(in: rendered.string, options: [], range: fullRenderedRange) { match, _, _ in
            guard
                let match,
                match.numberOfRanges >= 2,
                match.range.location != NSNotFound
            else { return }
            let lineRange = renderedString.lineRange(for: match.range)
            let leadingWhitespaceCount = max(0, match.range(at: 1).length)
            let indentBase = CGFloat(leadingWhitespaceCount) * 6
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
            style.lineSpacing = 2
            style.firstLineHeadIndent = indentBase
            style.headIndent = indentBase + 20
            rendered.addAttribute(.paragraphStyle, value: style, range: lineRange)
        }

        // fenced code block：优先保证可见背景。按围栏行成对识别，并给中间正文区间加样式。
        let fenceRegex = try? NSRegularExpression(pattern: "^[ \\t]*```.*$", options: [.anchorsMatchLines])
        if let fenceRegex {
            let fenceMatches = fenceRegex.matches(in: rendered.string, options: [], range: fullRenderedRange)
            var i = 0
            while i + 1 < fenceMatches.count {
                let openLine = renderedString.lineRange(for: fenceMatches[i].range)
                let closeLine = renderedString.lineRange(for: fenceMatches[i + 1].range)
                let start = openLine.location + openLine.length
                let end = closeLine.location
                if end > start {
                    let codeRange = NSRange(location: start, length: end - start)
                    let blockFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                    rendered.addAttribute(.font, value: blockFont, range: codeRange)
                    rendered.addAttribute(
                        .backgroundColor,
                        value: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                        range: codeRange
                    )

                    let codeParagraph = NSMutableParagraphStyle()
                    codeParagraph.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
                    codeParagraph.lineSpacing = 2
                    codeParagraph.firstLineHeadIndent = 8
                    codeParagraph.headIndent = 8
                    rendered.addAttribute(.paragraphStyle, value: codeParagraph, range: codeRange)
                }
                i += 2
            }
        }

        // 行内代码与加粗：去掉标记符并应用样式（跳过围栏代码块内部）。
        let tableLineIndices = Set(
            MarkdownPreviewTableLayout.findBlocks(
                in: markdown.components(separatedBy: "\n"),
                separatorRegex: Self.tableSeparatorRegex
            ).flatMap { $0.startLine..<$0.endLine }
        )
        applyInlineCodeSpans(in: rendered, excludedLineIndices: tableLineIndices)
        applyInlineBoldSpans(in: rendered, excludedLineIndices: tableLineIndices)

        // 表格必须在行内标记处理后再排版，否则 ** / ` 会破坏列对齐。
        applyMarkdownTableLayout(
            in: rendered,
            layoutWidth: layoutWidth
        )

        applyHorizontalRules(in: rendered, layoutWidth: layoutWidth)

        textView.textStorage?.setAttributedString(rendered)
    }

    private func applyHorizontalRules(
        in rendered: NSMutableAttributedString,
        layoutWidth: CGFloat?
    ) {
        let lines = rendered.string.components(separatedBy: "\n")
        let tableLineIndices = Set(
            MarkdownPreviewTableLayout.findBlocks(
                in: lines,
                separatorRegex: Self.tableSeparatorRegex
            ).flatMap { $0.startLine..<$0.endLine }
        )
        let hrLineIndices = MarkdownPreviewHorizontalRule.horizontalRuleLineIndices(
            in: lines,
            skipLineIndices: tableLineIndices
        )
        guard !hrLineIndices.isEmpty else { return }

        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let separatorColor = NSColor.separatorColor
        var lineMap = lineRanges(in: rendered.string as NSString)

        for lineIndex in hrLineIndices.reversed() {
            guard lineIndex < lines.count, lineIndex < lineMap.count else { continue }
            let originalLine = lines[lineIndex]
            let indent = MarkdownPreviewHorizontalRule.leadingIndent(originalLine)
            let renderedLine = MarkdownPreviewHorizontalRule.renderLine(
                indent: indent,
                availableWidth: layoutWidth,
                font: font
            )
            rendered.replaceCharacters(in: lineMap[lineIndex], with: renderedLine)
        }

        lineMap = lineRanges(in: rendered.string as NSString)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byClipping
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacingBefore = 4
        paragraphStyle.paragraphSpacing = 4

        for lineIndex in hrLineIndices {
            guard lineIndex < lineMap.count else { continue }
            let lineRange = lineMap[lineIndex]
            rendered.addAttribute(.font, value: font, range: lineRange)
            rendered.addAttribute(.foregroundColor, value: separatorColor, range: lineRange)
            rendered.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
        }
    }

    private func lineRanges(in text: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var offset = 0
        for line in text.components(separatedBy: "\n") {
            let length = (line as NSString).length
            ranges.append(NSRange(location: offset, length: length))
            offset += length + 1
        }
        return ranges
    }

    private func applyMarkdownTableLayout(
        in rendered: NSMutableAttributedString,
        layoutWidth: CGFloat?
    ) {
        let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let separatorColor = NSColor.separatorColor
        let layoutOptions = MarkdownPreviewTableLayout.LayoutOptions(availableWidth: layoutWidth)
        let lines = rendered.string.components(separatedBy: "\n")
        let blocks = MarkdownPreviewTableLayout.findBlocks(in: lines, separatorRegex: Self.tableSeparatorRegex)
        guard !blocks.isEmpty else { return }

        var tableDisplayLineIndices = Set<Int>()

        for block in blocks.reversed() {
            guard let formatted = MarkdownPreviewTableLayout.formatBlock(
                lines: lines,
                block: block,
                font: monoFont,
                options: layoutOptions
            ) else { continue }

            var lineMap = lineRanges(in: rendered.string as NSString)
            guard block.startLine < lineMap.count, block.endLine > 0, block.endLine - 1 < lineMap.count else {
                continue
            }

            let blockStart = lineMap[block.startLine].location
            let lastLineRange = lineMap[block.endLine - 1]
            let blockRange = NSRange(
                location: blockStart,
                length: lastLineRange.location + lastLineRange.length - blockStart
            )
            rendered.replaceCharacters(in: blockRange, with: formatted.lines.joined(separator: "\n"))

            lineMap = lineRanges(in: rendered.string as NSString)
            let displayRange = block.startLine..<(block.startLine + formatted.lines.count)
            tableDisplayLineIndices.formUnion(displayRange)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byClipping
            paragraphStyle.lineSpacing = 2
            paragraphStyle.tabStops = formatted.tabStopLocations.map {
                NSTextTab(textAlignment: .left, location: $0, options: [:])
            }
            paragraphStyle.defaultTabInterval = 1_000

            for (offset, lineIndex) in displayRange.enumerated() {
                guard lineIndex < lineMap.count else { continue }
                let lineRange = lineMap[lineIndex]
                rendered.addAttribute(.font, value: monoFont, range: lineRange)
                rendered.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)

                if formatted.separatorLineIndices.contains(offset) {
                    rendered.addAttribute(.foregroundColor, value: separatorColor, range: lineRange)
                }
            }
        }

        applyInlineCodeSpans(in: rendered, allowedLineIndices: tableDisplayLineIndices)
        applyInlineBoldSpans(in: rendered, allowedLineIndices: tableDisplayLineIndices)
    }

    private func shouldProcessLine(
        _ lineIndex: Int,
        allowedLineIndices: Set<Int>?,
        excludedLineIndices: Set<Int>?
    ) -> Bool {
        if let allowedLineIndices {
            return allowedLineIndices.contains(lineIndex)
        }
        if let excludedLineIndices {
            return !excludedLineIndices.contains(lineIndex)
        }
        return true
    }

    /// 围栏代码块（含 ``` 行与中间正文）在全文中的区间，供行内格式跳过。
    private func fencedCodeBlockRanges(in text: NSString) -> [NSRange] {
        let fullRange = NSRange(location: 0, length: text.length)
        let fenceRegex = try? NSRegularExpression(pattern: "^[ \\t]*```.*$", options: [.anchorsMatchLines])
        guard let fenceRegex else { return [] }
        let fenceMatches = fenceRegex.matches(in: text as String, options: [], range: fullRange)
        var ranges: [NSRange] = []
        ranges.reserveCapacity(fenceMatches.count / 2)
        var i = 0
        while i + 1 < fenceMatches.count {
            let openLine = text.lineRange(for: fenceMatches[i].range)
            let closeLine = text.lineRange(for: fenceMatches[i + 1].range)
            let blockEnd = closeLine.location + closeLine.length
            ranges.append(NSRange(location: openLine.location, length: blockEnd - openLine.location))
            i += 2
        }
        return ranges
    }

    private func range(_ range: NSRange, intersectsAny excluded: [NSRange]) -> Bool {
        excluded.contains { NSIntersectionRange(range, $0).length > 0 }
    }

    private func rangeHasAttribute(
        _ key: NSAttributedString.Key,
        in rendered: NSAttributedString,
        range: NSRange
    ) -> Bool {
        var found = false
        rendered.enumerateAttribute(key, in: range, options: []) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    private func applyBoldFont(to rendered: NSMutableAttributedString, range: NSRange) {
        rendered.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let baseFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            rendered.addAttribute(.font, value: boldFont, range: subRange)
        }
    }

    /// 行内 `` `code` ``：等宽字体 + 浅背景，用于 UI 标签、路径片段等引用文本。
    private func applyInlineCodeSpans(
        in rendered: NSMutableAttributedString,
        allowedLineIndices: Set<Int>? = nil,
        excludedLineIndices: Set<Int>? = nil
    ) {
        let text = rendered.string as NSString
        let excludeRanges = fencedCodeBlockRanges(in: text)
        guard let regex = try? NSRegularExpression(pattern: "`([^`\\n]+)`", options: []) else { return }
        let fullRange = NSRange(location: 0, length: text.length)
        let matches = regex.matches(in: rendered.string, options: [], range: fullRange)
        let inlineCodeBackground = NSColor.quaternaryLabelColor.withAlphaComponent(0.16)

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2, match.range(at: 1).location != NSNotFound else { continue }
            if range(match.range, intersectsAny: excludeRanges) { continue }
            if !shouldProcessLine(
                lineIndex(for: match.range, in: text),
                allowedLineIndices: allowedLineIndices,
                excludedLineIndices: excludedLineIndices
            ) { continue }

            let contentRange = match.range(at: 1)
            let content = text.substring(with: contentRange)
            rendered.replaceCharacters(in: match.range, with: content)

            let styledRange = NSRange(location: match.range.location, length: contentRange.length)
            let monoSize: CGFloat
            if let existing = rendered.attribute(.font, at: styledRange.location, effectiveRange: nil) as? NSFont {
                monoSize = existing.pointSize
            } else {
                monoSize = NSFont.systemFontSize
            }
            let codeFont = NSFont.monospacedSystemFont(ofSize: monoSize, weight: .regular)
            rendered.addAttribute(.font, value: codeFont, range: styledRange)
            rendered.addAttribute(.backgroundColor, value: inlineCodeBackground, range: styledRange)
        }
    }

    /// 行内 `**bold**`：去掉星号并加粗（跳过围栏代码块与已标记的行内代码）。
    private func applyInlineBoldSpans(
        in rendered: NSMutableAttributedString,
        allowedLineIndices: Set<Int>? = nil,
        excludedLineIndices: Set<Int>? = nil
    ) {
        let text = rendered.string as NSString
        let excludeRanges = fencedCodeBlockRanges(in: text)
        guard let regex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: []) else { return }
        let fullRange = NSRange(location: 0, length: text.length)
        let matches = regex.matches(in: rendered.string, options: [], range: fullRange)

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2, match.range(at: 1).location != NSNotFound else { continue }
            if range(match.range, intersectsAny: excludeRanges) { continue }
            if !shouldProcessLine(
                lineIndex(for: match.range, in: text),
                allowedLineIndices: allowedLineIndices,
                excludedLineIndices: excludedLineIndices
            ) { continue }
            if rangeHasAttribute(.backgroundColor, in: rendered, range: match.range) { continue }

            let contentRange = match.range(at: 1)
            let content = text.substring(with: contentRange)
            rendered.replaceCharacters(in: match.range, with: content)

            let styledRange = NSRange(location: match.range.location, length: contentRange.length)
            applyBoldFont(to: rendered, range: styledRange)
        }
    }

    private func lineIndex(for range: NSRange, in text: NSString) -> Int {
        guard range.location <= text.length else { return 0 }
        let prefix = text.substring(to: range.location)
        return prefix.filter { $0 == "\n" }.count
    }

    private func applyTextContainerInset(_ inset: CGFloat, to textView: NSTextView) {
        textView.textContainerInset = NSSize(width: inset, height: inset)
    }

    private func applyScale(_ target: CGFloat, to textView: NSTextView, context: Context) {
        let clamped = min(max(target, 0.5), 3.0)
        let current = context.coordinator.currentScale
        guard abs(clamped - current) > 0.0001 else { return }
        let factor = clamped / max(current, 0.0001)
        textView.scaleUnitSquare(to: NSSize(width: factor, height: factor))
        context.coordinator.currentScale = clamped
    }

    final class Coordinator {
        @Binding var searchMatchCount: Int
        var searchCurrentIndexBinding: Binding<Int>
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var previewTextSelectionActive: Binding<Bool>?
        let wrapLayout = PreviewTextWrapLayoutCoordinator()
        var lastMarkdown: String = ""
        var lastZoomScale: CGFloat = 1.0
        var textContentInset: CGFloat = 0
        var currentScale: CGFloat = 1.0
        var lastTableLayoutWidth: CGFloat = 0
        var relayoutMarkdown: ((NSTextView, NSScrollView) -> Void)?
        var lastSearchQuery: String = ""
        var lastSearchNextToken: UInt = 0
        var lastSearchPrevToken: UInt = 0
        var searchCurrentIndex: Int = 0
        var searchMatchRanges: [NSRange] = []
        var lastHighlightedSearchRanges: [NSRange] = []
        private var firstResponderObserver: NSObjectProtocol?
        private var tableLayoutWidthObserver: NSObjectProtocol?

        init(searchMatchCount: Binding<Int>, searchCurrentIndex: Binding<Int>) {
            _searchMatchCount = searchMatchCount
            searchCurrentIndexBinding = searchCurrentIndex
        }

        func installTableLayoutWidthTracking() {
            if let tableLayoutWidthObserver {
                NotificationCenter.default.removeObserver(tableLayoutWidthObserver)
            }
            guard let scrollView else { return }

            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollView.contentView.postsFrameChangedNotifications = true
            tableLayoutWidthObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.handleTableLayoutWidthChange()
            }
        }

        private func handleTableLayoutWidthChange() {
            guard let scrollView, let textView, let relayoutMarkdown else { return }
            relayoutMarkdown(textView, scrollView)
        }

        private func publishSearchCurrentIndex() {
            if searchCurrentIndexBinding.wrappedValue != searchCurrentIndex {
                searchCurrentIndexBinding.wrappedValue = searchCurrentIndex
            }
        }

        func updateSearchIfNeeded(
            textView: NSTextView,
            searchQuery: String,
            searchNextToken: UInt,
            searchPrevToken: UInt
        ) {
            if lastSearchQuery != searchQuery {
                lastSearchQuery = searchQuery
                searchCurrentIndex = 0
                applySearchHighlightsInPlace(
                    textView: textView,
                    scrollToCurrent: !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            if lastSearchNextToken != searchNextToken {
                lastSearchNextToken = searchNextToken
                guard !searchMatchRanges.isEmpty else { return }
                searchCurrentIndex = PreviewTextSearchHighlighter.advanceMatchIndex(
                    current: searchCurrentIndex,
                    matchCount: searchMatchRanges.count,
                    backward: false
                )
                applySearchHighlightsInPlace(textView: textView, scrollToCurrent: true)
            }

            if lastSearchPrevToken != searchPrevToken {
                lastSearchPrevToken = searchPrevToken
                guard !searchMatchRanges.isEmpty else { return }
                searchCurrentIndex = PreviewTextSearchHighlighter.advanceMatchIndex(
                    current: searchCurrentIndex,
                    matchCount: searchMatchRanges.count,
                    backward: true
                )
                applySearchHighlightsInPlace(textView: textView, scrollToCurrent: true)
            }
        }

        func applySearchHighlightsInPlace(textView: NSTextView, scrollToCurrent: Bool) {
            guard let storage = textView.textStorage else { return }

            PreviewTextSearchHighlighter.clearHighlights(in: storage, ranges: lastHighlightedSearchRanges)
            lastHighlightedSearchRanges = []

            let query = lastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                searchMatchRanges = []
                searchCurrentIndex = 0
                if searchMatchCount != 0 { searchMatchCount = 0 }
                publishSearchCurrentIndex()
                return
            }

            searchMatchRanges = PreviewTextSearchHighlighter.findMatchRanges(of: query, in: storage.string)
            if searchMatchRanges.isEmpty {
                searchCurrentIndex = 0
            } else {
                searchCurrentIndex = min(searchCurrentIndex, searchMatchRanges.count - 1)
            }

            if searchMatchCount != searchMatchRanges.count {
                searchMatchCount = searchMatchRanges.count
            }
            publishSearchCurrentIndex()

            guard !searchMatchRanges.isEmpty else { return }

            let result = PreviewTextSearchHighlighter.applyHighlights(
                in: storage,
                query: query,
                currentIndex: searchCurrentIndex,
                textView: textView,
                scrollToCurrent: scrollToCurrent
            )
            lastHighlightedSearchRanges = result.applied
        }

        deinit {
            if let firstResponderObserver {
                NotificationCenter.default.removeObserver(firstResponderObserver)
            }
            if let tableLayoutWidthObserver {
                NotificationCenter.default.removeObserver(tableLayoutWidthObserver)
            }
        }

        func installFocusTracking(for textView: NSTextView) {
            if let firstResponderObserver {
                NotificationCenter.default.removeObserver(firstResponderObserver)
            }
            firstResponderObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updatePreviewTextSelectionActive()
            }
            updatePreviewTextSelectionActive()
        }

        func updatePreviewTextSelectionActive() {
            guard let textView else {
                previewTextSelectionActive?.wrappedValue = false
                return
            }
            previewTextSelectionActive?.wrappedValue = textView.window?.firstResponder === textView
        }
    }
}
