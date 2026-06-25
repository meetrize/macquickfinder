import SwiftUI
import AppKit

struct MarkdownFilePreview: NSViewRepresentable {
    let markdown: String
    let wrapLines: Bool
    @Binding var zoomScale: CGFloat
    @Binding var previewTextSelectionActive: Bool
    @Binding var searchQuery: String
    @Binding var searchNextToken: UInt
    @Binding var searchMatchCount: Int

    private static let tableSeparatorRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: "^\\s*\\|?\\s*:?-{2,}:?\\s*(\\|\\s*:?-{2,}:?\\s*)+\\|?\\s*$",
            options: []
        )
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(searchMatchCount: $searchMatchCount)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapLines
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = PreviewCodeTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.autoresizingMask = wrapLines ? [.width] : []
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wrapLines
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        if !wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.previewTextSelectionActive = $previewTextSelectionActive
        textView.onInteractionStateChanged = { [weak coordinator = context.coordinator] in
            coordinator?.updatePreviewTextSelectionActive()
        }
        context.coordinator.installFocusTracking(for: textView)
        context.coordinator.currentScale = 1.0
        context.coordinator.lastMarkdown = markdown

        applyMarkdown(markdown, to: textView)
        applyScale(zoomScale, to: textView, context: context)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        scrollView.hasHorizontalScroller = !wrapLines
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.autoresizingMask = wrapLines ? [.width] : []
        textView.isHorizontallyResizable = !wrapLines
        if wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        if context.coordinator.lastMarkdown != markdown {
            applyMarkdown(markdown, to: textView)
            context.coordinator.lastMarkdown = markdown
            context.coordinator.searchCurrentIndex = 0
            context.coordinator.lastHighlightedSearchRanges = []
            textView.scrollToBeginningOfDocument(nil)
        }

        applyScale(zoomScale, to: textView, context: context)
        context.coordinator.updateSearchIfNeeded(
            textView: textView,
            searchQuery: searchQuery,
            searchNextToken: searchNextToken
        )
    }

    private func applyMarkdown(_ markdown: String, to textView: NSTextView) {
        // 以原始文本作为预览基准，保证换行/缩进完全保留，再做轻量样式增强。
        // 表格需要额外做一次“列宽对齐”，才能在等宽字体下呈现出表格外观。
        let formattedMarkdown = formatMarkdownTables(markdown)
        let rendered = NSMutableAttributedString(string: formattedMarkdown)

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
                    codeParagraph.lineBreakMode = .byClipping
                    codeParagraph.lineSpacing = 2
                    codeParagraph.firstLineHeadIndent = 8
                    codeParagraph.headIndent = 8
                    rendered.addAttribute(.paragraphStyle, value: codeParagraph, range: codeRange)
                }
                i += 2
            }
        }

        // 表格不希望在窄窗口里自动换行，否则竖线对齐会被破坏。
        if wrapLines {
            applyNoWrapForMarkdownTables(in: rendered)
        }

        // 表格竖线/分隔符对齐依赖等宽字体；只对表格块应用等宽字体即可。
        applyMonospaceFontForMarkdownTables(in: rendered)

        textView.textStorage?.setAttributedString(rendered)
    }

    private func formatMarkdownTables(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var out: [String] = []
        out.reserveCapacity(lines.count)

        func isWideScalar(_ scalar: UnicodeScalar) -> Bool {
            switch scalar.value {
            // CJK Unified Ideographs + Ext A
            case 0x3400...0x4DBF, 0x4E00...0x9FFF,
                // CJK Compatibility Ideographs
                0xF900...0xFAFF,
                // Hiragana / Katakana / Hangul
                0x3040...0x30FF, 0xAC00...0xD7AF,
                // CJK symbols & punctuation, full-width forms
                0x3000...0x303F, 0xFF01...0xFF60, 0xFFE0...0xFFE6:
                return true
            default:
                return false
            }
        }

        func displayWidth(_ text: String) -> Int {
            var width = 0
            for scalar in text.unicodeScalars {
                // 控制字符不计宽
                if CharacterSet.controlCharacters.contains(scalar) {
                    continue
                }
                width += isWideScalar(scalar) ? 2 : 1
            }
            return max(0, width)
        }

        func isFenceLine(_ line: String) -> Bool {
            line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
        }

        func isTableRowLine(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let pipeCount = trimmed.filter { $0 == "|" }.count
            return pipeCount >= 2 && trimmed.contains("|")
        }

        func isSeparatorLine(_ line: String) -> Bool {
            guard let re = Self.tableSeparatorRegex else { return false }
            let range = NSRange(location: 0, length: (line as NSString).length)
            return re.firstMatch(in: line, options: [], range: range) != nil
        }

        func leadingIndent(_ line: String) -> String {
            let prefix = line.prefix { $0 == " " || $0 == "\t" }
            return String(prefix)
        }

        func parseCells(_ line: String) -> [String] {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            var core = trimmed
            if core.hasPrefix("|") { core.removeFirst() }
            if core.hasSuffix("|") { core.removeLast() }
            let parts = core.split(separator: "|", omittingEmptySubsequences: false)
            return parts.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        var inFence = false
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if isFenceLine(line) {
                inFence.toggle()
                out.append(line)
                i += 1
                continue
            }
            if inFence {
                out.append(line)
                i += 1
                continue
            }

            // 识别：表头行 + 分隔行 + 多行 body
            if i + 1 < lines.count, isTableRowLine(lines[i]), isSeparatorLine(lines[i + 1]) {
                let headerLine = lines[i]
                let indent = leadingIndent(headerLine)

                var block: [String] = [headerLine, lines[i + 1]]
                var j = i + 2
                while j < lines.count, isTableRowLine(lines[j]) {
                    block.append(lines[j])
                    j += 1
                }

                // 解析 header + body，计算列宽（按等宽字体近似使用字符数）
                let headerCells = parseCells(block[0])
                var bodyRows: [[String]] = []
                if block.count > 2 {
                    bodyRows = block.dropFirst(2).map { parseCells($0) }
                }
                let colCount = max(
                    headerCells.count,
                    bodyRows.map(\.count).max() ?? 0
                )

                var widths = Array(repeating: 1, count: colCount)
                func updateWidths(with row: [String]) {
                    for col in 0..<colCount {
                        let cell = col < row.count ? row[col] : ""
                        widths[col] = max(widths[col], displayWidth(cell))
                    }
                }
                updateWidths(with: headerCells)
                for r in bodyRows { updateWidths(with: r) }

                func formatRow(_ cells: [String], widths: [Int], indent: String) -> String {
                    let formattedCells: [String] = (0..<widths.count).map { col in
                        let cell = col < cells.count ? cells[col] : ""
                        let pad = max(0, widths[col] - displayWidth(cell))
                        return " " + cell + String(repeating: " ", count: pad) + " "
                    }
                    return indent + "|" + formattedCells.joined(separator: "|") + "|"
                }

                // separator 行：用统一长度的 --- 视觉对齐（简单版）
                func formatSeparator(widths: [Int], indent: String) -> String {
                    let parts: [String] = widths.map { w in
                        let dashCount = max(3, w)
                        return " " + String(repeating: "-", count: dashCount) + " "
                    }
                    return indent + "|" + parts.joined(separator: "|") + "|"
                }

                out.append(formatRow(headerCells, widths: widths, indent: indent))
                out.append(formatSeparator(widths: widths, indent: indent))
                if block.count > 2 {
                    for rowLine in block.dropFirst(2) {
                        let cells = parseCells(rowLine)
                        out.append(formatRow(cells, widths: widths, indent: indent))
                    }
                }

                i = j
                continue
            }

            out.append(line)
            i += 1
        }

        return out.joined(separator: "\n")
    }

    private func applyNoWrapForMarkdownTables(in rendered: NSMutableAttributedString) {
        // 用 line-by-line 扫描找表格行块，然后强制 those line 的 lineBreakMode = byClipping
        var inFence = false

        func isFenceLine(_ s: String) -> Bool {
            s.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
        }

        func isTableRowLine(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let pipeCount = trimmed.filter { $0 == "|" }.count
            return pipeCount >= 2 && trimmed.contains("|")
        }

        func isSeparatorLine(_ s: String) -> Bool {
            guard let re = Self.tableSeparatorRegex else { return false }
            let range = NSRange(location: 0, length: (s as NSString).length)
            return re.firstMatch(in: s, options: [], range: range) != nil
        }

        // 逐行分割并计算 offset，得到每一行在 attributedString 内的 NSRange。
        var lineRanges: [NSRange] = []
        var lineTexts: [String] = []
        lineRanges.reserveCapacity(64)
        lineTexts.reserveCapacity(64)
        var offset = 0
        let rawLines = rendered.string.components(separatedBy: "\n")
        for rawLine in rawLines {
            let length = (rawLine as NSString).length
            lineRanges.append(NSRange(location: offset, length: length))
            lineTexts.append(rawLine)
            offset += length + 1 // + '\n'
        }

        guard !lineTexts.isEmpty else { return }

        func updateLine(_ range: NSRange) {
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byClipping
            style.lineSpacing = 2
            rendered.addAttribute(.paragraphStyle, value: style, range: range)
        }

        var i = 0
        while i + 1 < lineTexts.count {
            let line = lineTexts[i]
            if isFenceLine(line) {
                inFence.toggle()
                i += 1
                continue
            }
            if inFence {
                i += 1
                continue
            }

            if isTableRowLine(line), isSeparatorLine(lineTexts[i + 1]) {
                // 找块结束
                var j = i + 2
                while j < lineTexts.count, isTableRowLine(lineTexts[j]) {
                    j += 1
                }
                // i ..< j 都是表格行：强制不换行
                for k in i..<j {
                    updateLine(lineRanges[k])
                }
                i = j
            } else {
                i += 1
            }
        }
    }

    private func applyMonospaceFontForMarkdownTables(in rendered: NSMutableAttributedString) {
        var inFence = false

        func isFenceLine(_ s: String) -> Bool {
            s.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
        }

        func isTableRowLine(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let pipeCount = trimmed.filter { $0 == "|" }.count
            return pipeCount >= 2 && trimmed.contains("|")
        }

        func isSeparatorLine(_ s: String) -> Bool {
            guard let re = Self.tableSeparatorRegex else { return false }
            let range = NSRange(location: 0, length: (s as NSString).length)
            return re.firstMatch(in: s, options: [], range: range) != nil
        }

        var offset = 0
        let rawLines = rendered.string.components(separatedBy: "\n")
        let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        var i = 0
        while i + 1 < rawLines.count {
            let line = rawLines[i]
            if isFenceLine(line) {
                inFence.toggle()
                offset += (line as NSString).length + 1
                i += 1
                continue
            }
            if inFence {
                offset += (line as NSString).length + 1
                i += 1
                continue
            }

            if isTableRowLine(line), isSeparatorLine(rawLines[i + 1]) {
                // 找表格块结束
                var j = i + 2
                while j < rawLines.count, isTableRowLine(rawLines[j]) {
                    j += 1
                }

                // i ..< j 都是表格行：应用等宽字体
                var lineOffset = offset
                for k in i..<j {
                    let lineText = rawLines[k]
                    let length = (lineText as NSString).length
                    let lineRange = NSRange(location: lineOffset, length: length)
                    rendered.addAttribute(.font, value: monoFont, range: lineRange)
                    lineOffset += length + 1
                }

                // 跳过已处理的块
                let lastLine = rawLines[j - 1]
                offset += ((lastLine as NSString).length + 1) * (j - i)
                i = j
                continue
            }

            offset += (line as NSString).length + 1
            i += 1
        }
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
        weak var textView: NSTextView?
        var previewTextSelectionActive: Binding<Bool>?
        var lastMarkdown: String = ""
        var currentScale: CGFloat = 1.0
        var lastSearchQuery: String = ""
        var lastSearchNextToken: UInt = 0
        var searchCurrentIndex: Int = 0
        var searchMatchRanges: [NSRange] = []
        var lastHighlightedSearchRanges: [NSRange] = []
        private var firstResponderObserver: NSObjectProtocol?

        init(searchMatchCount: Binding<Int>) {
            _searchMatchCount = searchMatchCount
        }

        func updateSearchIfNeeded(textView: NSTextView, searchQuery: String, searchNextToken: UInt) {
            if lastSearchQuery != searchQuery {
                lastSearchQuery = searchQuery
                searchCurrentIndex = 0
                applySearchHighlightsInPlace(
                    textView: textView,
                    scrollToCurrent: !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            } else if lastSearchNextToken != searchNextToken {
                lastSearchNextToken = searchNextToken
                guard !searchMatchRanges.isEmpty else { return }
                searchCurrentIndex = (searchCurrentIndex + 1) % searchMatchRanges.count
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
