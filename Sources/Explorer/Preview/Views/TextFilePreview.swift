import SwiftUI
import AppKit

struct TextFilePreview: NSViewRepresentable {
    let text: String
    let fileExtension: String
    let wrapLines: Bool
    let fontSize: CGFloat
    let showLineNumbers: Bool
    var textContentInset: CGFloat = 0
    @Binding var displayMode: PreviewTextDisplayMode
    var onLiveContentChange: ((String) -> Void)?
    @Binding var previewTextSelectionActive: Bool
    @Binding var action: TextPreviewAction?
    @Binding var searchQuery: String
    @Binding var searchNextToken: UInt
    @Binding var searchPrevToken: UInt
    @Binding var searchMatchCount: Int
    @Binding var searchCurrentIndex: Int
    @Binding var contentSearchJumpLine: Int?
    @Binding var contentSearchJumpColumnUTF16: Int
    @Binding var contentSearchJumpToken: UInt
    /// session 级跳转世代；变化时强制走 updateNSView（同文件多次点击）。
    var contentSearchJumpEpoch: UInt = 0

    private var isEditing: Bool {
        displayMode == .editing
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            searchMatchCount: $searchMatchCount,
            searchCurrentIndex: $searchCurrentIndex,
            onLiveContentChange: onLiveContentChange
        )
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        PreviewScrollerChrome.applyPanelSafeBounds(to: scrollView)
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentView.drawsBackground = false
        
        let textView = PreviewCodeTextView()
        textView.allowsEditing = isEditing
        textView.isEditable = isEditing
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = !isEditing
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textContainer?.lineFragmentPadding = 0
        Self.applyTextContainerInset(to: textView, showLineNumbers: showLineNumbers, edgeInset: textContentInset)
        textView.textStorage?.setAttributedString(TextSyntaxHighlighter.makePlainText(text: text, fontSize: fontSize))
        PreviewTextWrapLayout.applyParagraphWrapStyle(to: textView, wrapLines: wrapLines)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.previewTextSelectionActive = $previewTextSelectionActive
        context.coordinator.lastDisplayMode = displayMode
        textView.onInteractionStateChanged = { [weak coordinator = context.coordinator] in
            coordinator?.updatePreviewTextSelectionActive()
        }
        context.coordinator.installSelectionTracking(for: textView)
        context.coordinator.installTextChangeTracking(for: textView, isEditing: isEditing)
        context.coordinator.wrapLayout.wrapLinesEnabled = wrapLines
        context.coordinator.wrapLayout.lastWrapLines = wrapLines
        context.coordinator.lastShowLineNumbers = showLineNumbers
        Self.configureLineNumbers(
            scrollView: scrollView,
            textView: textView,
            text: text,
            show: showLineNumbers,
            coordinator: context.coordinator
        )
        PreviewTextWrapLayout.configure(textView: textView, scrollView: scrollView, wrapLines: wrapLines)
        context.coordinator.wrapLayout.lastTrackedContentWidth = PreviewTextWrapLayout.effectiveContentWidth(for: scrollView)
        PreviewTextWrapLayout.installContentWidthTracking(
            scrollView: scrollView,
            textView: textView,
            coordinator: context.coordinator.wrapLayout
        )
        PreviewTextWrapLayout.scheduleDeferredLayout(textView: textView, scrollView: scrollView, wrapLines: wrapLines)
        if !isEditing {
            let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            context.coordinator.lastHighlightKey = "\(text.hashValue)|\(fileExtension)|\(fontSize)|\(isDark)"
            context.coordinator.applyHighlight(
                text: text,
                fileExtension: fileExtension,
                fontSize: fontSize,
                wrapLines: wrapLines,
                textView: textView
            )
        }
        if isEditing {
            context.coordinator.activateEditingFocus(on: textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentView.drawsBackground = false

        guard let textView = context.coordinator.textView else { return }
        context.coordinator.onLiveContentChange = onLiveContentChange

        if context.coordinator.lastDisplayMode != displayMode {
            context.coordinator.transitionDisplayMode(
                from: context.coordinator.lastDisplayMode,
                to: displayMode,
                text: text,
                fileExtension: fileExtension,
                fontSize: fontSize,
                wrapLines: wrapLines,
                textView: textView
            )
            context.coordinator.lastDisplayMode = displayMode
            context.coordinator.installTextChangeTracking(for: textView, isEditing: isEditing)
        }

        if let previewTextView = textView as? PreviewCodeTextView {
            previewTextView.allowsEditing = isEditing
        }
        textView.isEditable = isEditing
        textView.isRichText = !isEditing

        if !isEditing, textView.string != text {
            textView.textStorage?.setAttributedString(TextSyntaxHighlighter.makePlainText(text: text, fontSize: fontSize))
            textView.scrollToBeginningOfDocument(nil)
            context.coordinator.searchCurrentIndex = 0
            context.coordinator.lastHighlightKey = nil
            context.coordinator.lastHighlightedSearchRanges = []
            context.coordinator.lineNumberRuler?.updateRuleThickness(for: text)
            context.coordinator.lineNumberRuler?.needsDisplay = true
        }
        if textView.font?.pointSize != fontSize {
            textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        if !isEditing {
            let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let highlightKey = "\(text.hashValue)|\(fileExtension)|\(fontSize)|\(isDark)"
            if context.coordinator.lastHighlightKey != highlightKey {
                context.coordinator.lastHighlightKey = highlightKey
                context.coordinator.applyHighlight(
                    text: text,
                    fileExtension: fileExtension,
                    fontSize: fontSize,
                    wrapLines: wrapLines,
                    textView: textView
                )
            }
        }
        context.coordinator.wrapLayout.wrapLinesEnabled = wrapLines
        scrollView.tile()
        PreviewTextWrapLayout.configure(textView: textView, scrollView: scrollView, wrapLines: wrapLines)

        if context.coordinator.wrapLayout.lastWrapLines != wrapLines {
            context.coordinator.wrapLayout.lastWrapLines = wrapLines
            context.coordinator.wrapLayout.lastTrackedContentWidth = PreviewTextWrapLayout.effectiveContentWidth(for: scrollView)
            PreviewTextWrapLayout.applyParagraphWrapStyle(to: textView, wrapLines: wrapLines)
            if wrapLines {
                PreviewTextWrapLayout.syncWrapDocumentLayout(textView: textView, scrollView: scrollView)
            }
            textView.scrollToBeginningOfDocument(nil)
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.contentView.bounds.origin.y))
            PreviewTextWrapLayout.invalidateLayout(textView: textView)
            context.coordinator.lineNumberRuler?.needsDisplay = true
        } else if wrapLines {
            let width = PreviewTextWrapLayout.effectiveContentWidth(for: scrollView)
            if abs(width - context.coordinator.wrapLayout.lastTrackedContentWidth) > 0.5 {
                context.coordinator.wrapLayout.lastTrackedContentWidth = width
                PreviewTextWrapLayout.invalidateLayout(textView: textView)
            }
        }

        if context.coordinator.lastShowLineNumbers != showLineNumbers {
            context.coordinator.lastShowLineNumbers = showLineNumbers
            Self.configureLineNumbers(
                scrollView: scrollView,
                textView: textView,
                text: text,
                show: showLineNumbers,
                coordinator: context.coordinator
            )
            if wrapLines {
                PreviewTextWrapLayout.syncWrapDocumentLayout(textView: textView, scrollView: scrollView)
                PreviewTextWrapLayout.invalidateLayout(textView: textView)
            }
        }

        Self.applyTextContainerInset(to: textView, showLineNumbers: showLineNumbers, edgeInset: textContentInset)

        if let action {
            switch action {
            case .copyAll:
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(textView.string, forType: .string)
            case .scrollTop:
                textView.scrollToBeginningOfDocument(nil)
            case .scrollBottom:
                textView.scrollToEndOfDocument(nil)
            case .beginEdit, .save, .revert:
                break
            }
            DispatchQueue.main.async {
                switch action {
                case .copyAll, .scrollTop, .scrollBottom:
                    self.action = nil
                case .beginEdit, .save, .revert:
                    break
                }
            }
        }

        guard !isEditing else { return }

        let coordinator = context.coordinator
        let hasActiveContentSearchJump =
            contentSearchJumpLine != nil
            && (coordinator.lastContentSearchJumpToken != contentSearchJumpToken
                || coordinator.lastContentSearchJumpEpoch != contentSearchJumpEpoch
                || coordinator.pendingContentSearchJump != nil)

        if coordinator.lastSearchQuery != searchQuery {
            coordinator.lastSearchQuery = searchQuery
            coordinator.searchCurrentIndex = 0
            coordinator.applySearchHighlightsInPlace(
                textView: textView,
                // 有待处理的内容搜索跳转时不要滚到第 0 个匹配，避免盖住目标行。
                scrollToCurrent: !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !hasActiveContentSearchJump
            )
        }

        if coordinator.lastSearchNextToken != searchNextToken {
            coordinator.lastSearchNextToken = searchNextToken
            if coordinator.searchMatchRanges.isEmpty,
               !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                coordinator.applySearchHighlightsInPlace(textView: textView, scrollToCurrent: false)
            }
            guard !coordinator.searchMatchRanges.isEmpty else { return }
            coordinator.searchCurrentIndex = PreviewTextSearchHighlighter.advanceMatchIndex(
                current: coordinator.searchCurrentIndex,
                matchCount: coordinator.searchMatchRanges.count,
                backward: false
            )
            coordinator.applySearchHighlightsInPlace(
                textView: textView,
                scrollToCurrent: true
            )
        }

        if coordinator.lastSearchPrevToken != searchPrevToken {
            coordinator.lastSearchPrevToken = searchPrevToken
            if coordinator.searchMatchRanges.isEmpty,
               !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                coordinator.applySearchHighlightsInPlace(textView: textView, scrollToCurrent: false)
            }
            guard !coordinator.searchMatchRanges.isEmpty else { return }
            coordinator.searchCurrentIndex = PreviewTextSearchHighlighter.advanceMatchIndex(
                current: coordinator.searchCurrentIndex,
                matchCount: coordinator.searchMatchRanges.count,
                backward: true
            )
            coordinator.applySearchHighlightsInPlace(
                textView: textView,
                scrollToCurrent: true
            )
        }

        if (coordinator.lastContentSearchJumpToken != contentSearchJumpToken
            || coordinator.lastContentSearchJumpEpoch != contentSearchJumpEpoch),
           let jumpLine = contentSearchJumpLine {
            let didApply = coordinator.applyContentSearchJump(
                lineNumber: jumpLine,
                columnUTF16: contentSearchJumpColumnUTF16,
                textView: textView
            )
            if didApply {
                coordinator.lastContentSearchJumpToken = contentSearchJumpToken
                coordinator.lastContentSearchJumpEpoch = contentSearchJumpEpoch
                coordinator.pendingContentSearchJump = nil
            } else {
                coordinator.pendingContentSearchJump = Coordinator.PendingContentSearchJump(
                    lineNumber: jumpLine,
                    columnUTF16: contentSearchJumpColumnUTF16,
                    token: contentSearchJumpToken,
                    epoch: contentSearchJumpEpoch
                )
            }
        } else {
            coordinator.retryPendingContentSearchJumpIfNeeded(textView: textView)
        }
    }
    
    final class Coordinator {
        struct PendingContentSearchJump {
            let lineNumber: Int
            let columnUTF16: Int
            let token: UInt
            let epoch: UInt
        }

        @Binding var searchMatchCount: Int
        var searchCurrentIndexBinding: Binding<Int>
        var previewTextSelectionActive: Binding<Bool>?
        var onLiveContentChange: ((String) -> Void)?
        weak var textView: NSTextView?
        weak var lineNumberRuler: CodePreviewLineNumberRulerView?
        let wrapLayout = PreviewTextWrapLayoutCoordinator()
        var lastShowLineNumbers: Bool = false
        var lastDisplayMode: PreviewTextDisplayMode = .viewing
        var lastHighlightKey: String?
        var lastSearchQuery: String = ""
        var lastSearchNextToken: UInt = 0
        var lastSearchPrevToken: UInt = 0
        var lastContentSearchJumpToken: UInt = 0
        var lastContentSearchJumpEpoch: UInt = 0
        var pendingContentSearchJump: PendingContentSearchJump?
        var searchCurrentIndex: Int = 0
        var searchMatchRanges: [NSRange] = []
        var lastHighlightedSearchRanges: [NSRange] = []
        private var cachedSyntaxHighlight: NSAttributedString?
        private var renderWorkItem: DispatchWorkItem?
        private var generation: UInt64 = 0
        private var selectionObserver: NSObjectProtocol?
        private var firstResponderObserver: NSObjectProtocol?
        private var deferredJumpWorkItem: DispatchWorkItem?

        init(
            searchMatchCount: Binding<Int>,
            searchCurrentIndex: Binding<Int>,
            onLiveContentChange: ((String) -> Void)?
        ) {
            _searchMatchCount = searchMatchCount
            searchCurrentIndexBinding = searchCurrentIndex
            self.onLiveContentChange = onLiveContentChange
        }

        private func publishSearchCurrentIndex() {
            if searchCurrentIndexBinding.wrappedValue != searchCurrentIndex {
                searchCurrentIndexBinding.wrappedValue = searchCurrentIndex
            }
        }

        deinit {
            renderWorkItem?.cancel()
            deferredJumpWorkItem?.cancel()
            if let selectionObserver {
                NotificationCenter.default.removeObserver(selectionObserver)
            }
            if let firstResponderObserver {
                NotificationCenter.default.removeObserver(firstResponderObserver)
            }
        }

        func installTextChangeTracking(for textView: NSTextView, isEditing: Bool) {
            guard let previewTextView = textView as? PreviewCodeTextView else { return }
            if isEditing {
                previewTextView.onTextContentChanged = { [weak self, weak textView] in
                    guard let self, let textView else { return }
                    self.onLiveContentChange?(textView.string)
                }
            } else {
                previewTextView.onTextContentChanged = nil
            }
        }

        func activateEditingFocus(on textView: NSTextView) {
            DispatchQueue.main.async { [weak textView] in
                guard let textView, let window = textView.window else { return }
                guard window.makeFirstResponder(textView) else { return }
                let length = (textView.string as NSString).length
                textView.setSelectedRange(NSRange(location: length, length: 0))
                textView.scrollRangeToVisible(NSRange(location: length, length: 0))
                if let previewTextView = textView as? PreviewCodeTextView {
                    previewTextView.onInteractionStateChanged?()
                }
            }
        }

        func transitionDisplayMode(
            from oldMode: PreviewTextDisplayMode,
            to newMode: PreviewTextDisplayMode,
            text: String,
            fileExtension: String,
            fontSize: CGFloat,
            wrapLines: Bool,
            textView: NSTextView
        ) {
            renderWorkItem?.cancel()
            lastHighlightedSearchRanges = []
            searchMatchRanges = []
            if searchMatchCount != 0 { searchMatchCount = 0 }
            publishSearchCurrentIndex()

            switch newMode {
            case .editing:
                lastHighlightKey = nil
                if textView.string.isEmpty {
                    textView.string = text
                }
                textView.isRichText = false
                textView.isEditable = true
                if let previewTextView = textView as? PreviewCodeTextView {
                    previewTextView.allowsEditing = true
                }
                onLiveContentChange?(textView.string)
                activateEditingFocus(on: textView)
            case .viewing:
                textView.isEditable = false
                textView.isRichText = true
                if let previewTextView = textView as? PreviewCodeTextView {
                    previewTextView.allowsEditing = false
                }
                textView.textStorage?.setAttributedString(
                    TextSyntaxHighlighter.makePlainText(text: text, fontSize: fontSize)
                )
                PreviewTextWrapLayout.applyParagraphWrapStyle(to: textView, wrapLines: wrapLines)
                PreviewTextWrapLayout.invalidateLayout(textView: textView)
                let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                lastHighlightKey = "\(text.hashValue)|\(fileExtension)|\(fontSize)|\(isDark)"
                applyHighlight(
                    text: text,
                    fileExtension: fileExtension,
                    fontSize: fontSize,
                    wrapLines: wrapLines,
                    textView: textView
                )
            }

            _ = oldMode
        }

        func installSelectionTracking(for textView: NSTextView) {
            if let selectionObserver {
                NotificationCenter.default.removeObserver(selectionObserver)
            }
            if let firstResponderObserver {
                NotificationCenter.default.removeObserver(firstResponderObserver)
            }

            selectionObserver = NotificationCenter.default.addObserver(
                forName: NSTextView.didChangeSelectionNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                self?.updatePreviewTextSelectionActive()
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

        func applyContentSearchJump(lineNumber: Int, columnUTF16: Int, textView: NSTextView) -> Bool {
            guard PreviewTextSearchHighlighter.canRevealLine(lineNumber, in: textView.string) else {
                return false
            }

            applySearchHighlightsInPlace(textView: textView, scrollToCurrent: false)
            if let matchIndex = PreviewTextSearchHighlighter.matchIndex(
                lineNumber: lineNumber,
                columnUTF16: columnUTF16,
                in: textView.string,
                matchRanges: searchMatchRanges
            ) {
                searchCurrentIndex = matchIndex
                applySearchHighlightsInPlace(textView: textView, scrollToCurrent: true)
            } else {
                PreviewTextSearchHighlighter.scrollToLine(lineNumber, in: textView)
            }

            // 布局未完成时 scrollRangeToVisible 可能无效，下一帧再滚一次。
            scheduleDeferredScroll(toLine: lineNumber, columnUTF16: columnUTF16, textView: textView)
            return true
        }

        func retryPendingContentSearchJumpIfNeeded(textView: NSTextView) {
            guard let pending = pendingContentSearchJump else { return }
            let didApply = applyContentSearchJump(
                lineNumber: pending.lineNumber,
                columnUTF16: pending.columnUTF16,
                textView: textView
            )
            guard didApply else { return }
            lastContentSearchJumpToken = pending.token
            lastContentSearchJumpEpoch = pending.epoch
            pendingContentSearchJump = nil
        }

        private func scheduleDeferredScroll(toLine lineNumber: Int, columnUTF16: Int, textView: NSTextView) {
            deferredJumpWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                if let matchIndex = PreviewTextSearchHighlighter.matchIndex(
                    lineNumber: lineNumber,
                    columnUTF16: columnUTF16,
                    in: textView.string,
                    matchRanges: self.searchMatchRanges
                ), matchIndex < self.searchMatchRanges.count {
                    PreviewTextSearchHighlighter.scrollToRange(self.searchMatchRanges[matchIndex], in: textView)
                } else {
                    PreviewTextSearchHighlighter.scrollToLine(lineNumber, in: textView)
                }
            }
            deferredJumpWorkItem = work
            DispatchQueue.main.async(execute: work)
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
                lineNumberRuler?.needsDisplay = true
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

            guard !searchMatchRanges.isEmpty else {
                lineNumberRuler?.needsDisplay = true
                return
            }

            let result = PreviewTextSearchHighlighter.applyHighlights(
                in: storage,
                query: query,
                currentIndex: searchCurrentIndex,
                textView: textView,
                scrollToCurrent: scrollToCurrent
            )
            lastHighlightedSearchRanges = result.applied
            lineNumberRuler?.needsDisplay = true
        }

        func applyHighlight(
            text: String,
            fileExtension: String,
            fontSize: CGFloat,
            wrapLines: Bool,
            textView: NSTextView
        ) {
            generation &+= 1
            let currentGeneration = generation
            renderWorkItem?.cancel()
            let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

            var workItem: DispatchWorkItem!
            workItem = DispatchWorkItem { [weak self] in
                guard !workItem.isCancelled else { return }
                let highlighted = TextSyntaxHighlighter.highlightedText(
                    text: text,
                    fileExtension: fileExtension,
                    fontSize: fontSize,
                    isDark: isDark
                )
                DispatchQueue.main.async {
                    guard !workItem.isCancelled else { return }
                    guard let self, currentGeneration == self.generation else { return }
                    guard textView.string == text else { return }
                    self.cachedSyntaxHighlight = highlighted
                    let selectedRange = textView.selectedRange()
                    textView.textStorage?.setAttributedString(highlighted)
                    PreviewTextWrapLayout.applyParagraphWrapStyle(to: textView, wrapLines: wrapLines)
                    PreviewTextWrapLayout.invalidateLayout(textView: textView)
                    self.lastHighlightedSearchRanges = []
                    // 整段替换 attributedString 会打乱滚动位置；有搜索时一律滚回当前匹配。
                    self.applySearchHighlightsInPlace(
                        textView: textView,
                        scrollToCurrent: !self.lastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    if selectedRange.location <= textView.string.utf16.count {
                        let nsLength = (textView.string as NSString).length
                        let clampedLength = min(
                            selectedRange.length,
                            max(0, nsLength - selectedRange.location)
                        )
                        textView.setSelectedRange(NSRange(location: selectedRange.location, length: clampedLength))
                    }
                    self.lineNumberRuler?.updateRuleThickness(for: text)
                    self.lineNumberRuler?.needsDisplay = true
                }
            }
            renderWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }

    private static let lineNumberGutterGap: CGFloat = 4

    private static func applyTextContainerInset(to textView: NSTextView, showLineNumbers: Bool, edgeInset: CGFloat) {
        textView.textContainerInset = NSSize(
            width: edgeInset + (showLineNumbers ? lineNumberGutterGap : 0),
            height: edgeInset
        )
    }

    private static func configureLineNumbers(
        scrollView: NSScrollView,
        textView: NSTextView,
        text: String,
        show: Bool,
        coordinator: Coordinator
    ) {
        scrollView.hasVerticalRuler = show
        scrollView.rulersVisible = show
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentView.drawsBackground = false
        if show {
            let ruler = coordinator.lineNumberRuler ?? CodePreviewLineNumberRulerView(
                scrollView: scrollView,
                textView: textView
            )
            ruler.textView = textView
            ruler.updateRuleThickness(for: text)
            scrollView.verticalRulerView = ruler
            coordinator.lineNumberRuler = ruler
            ruler.needsDisplay = true
        } else {
            scrollView.verticalRulerView = nil
            coordinator.lineNumberRuler = nil
        }
    }

}
