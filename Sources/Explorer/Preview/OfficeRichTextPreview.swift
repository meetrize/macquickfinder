import AppKit
import SwiftUI

/// docx 富文本预览：PreviewCodeTextView + scaleUnitSquare，缩放行为与 TextEdit / Markdown 预览一致。
struct OfficeRichTextPreview: NSViewRepresentable {
    let attributedText: NSAttributedString
    let wrapLines: Bool
    var textContentInset: CGFloat = 0
    let zoomScale: CGFloat
    @Binding var previewTextSelectionActive: Bool
    @Binding var searchQuery: String
    @Binding var searchNextToken: UInt
    @Binding var searchPrevToken: UInt
    @Binding var searchMatchCount: Int
    @Binding var searchCurrentIndex: Int

    func makeCoordinator() -> Coordinator { Coordinator(
        searchMatchCount: $searchMatchCount,
        searchCurrentIndex: $searchCurrentIndex
    ) }

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
        textView.textContainer?.lineFragmentPadding = 0
        applyTextContainerInset(textContentInset, to: textView)
        configureLayout(textView: textView, scrollView: scrollView, wrapLines: wrapLines)
        textView.textStorage?.setAttributedString(attributedText)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.previewTextSelectionActive = $previewTextSelectionActive
        textView.onInteractionStateChanged = { [weak coordinator = context.coordinator] in
            coordinator?.updatePreviewTextSelectionActive()
        }
        context.coordinator.installFocusTracking(for: textView)
        context.coordinator.currentScale = 1.0
        context.coordinator.contentSignature = 0
        applyScale(zoomScale, to: textView, context: context)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        scrollView.hasHorizontalScroller = !wrapLines
        configureLayout(textView: textView, scrollView: scrollView, wrapLines: wrapLines)
        applyTextContainerInset(textContentInset, to: textView)

        let signature = attributedText.length ^ attributedText.string.hashValue
        if context.coordinator.contentSignature != signature {
            context.coordinator.contentSignature = signature
            textView.textStorage?.setAttributedString(attributedText)
            context.coordinator.searchCurrentIndex = 0
            context.coordinator.lastHighlightedSearchRanges = []
            let current = context.coordinator.currentScale
            if abs(current - 1.0) > 0.0001 {
                textView.scaleUnitSquare(to: NSSize(width: 1.0 / current, height: 1.0 / current))
            }
            context.coordinator.currentScale = 1.0
            textView.scrollToBeginningOfDocument(nil)
        }

        applyScale(zoomScale, to: textView, context: context)
        context.coordinator.updateSearchIfNeeded(
            textView: textView,
            searchQuery: searchQuery,
            searchNextToken: searchNextToken,
            searchPrevToken: searchPrevToken
        )
    }

    private func applyTextContainerInset(_ inset: CGFloat, to textView: NSTextView) {
        textView.textContainerInset = NSSize(width: inset, height: inset)
    }

    private func configureLayout(textView: NSTextView, scrollView: NSScrollView, wrapLines: Bool) {
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.autoresizingMask = wrapLines ? [.width] : []
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wrapLines
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
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
    }

    private func applyScale(_ target: CGFloat, to textView: NSTextView, context: Context) {
        let clamped = min(max(target, 0.25), 5.0)
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
        var previewTextSelectionActive: Binding<Bool>?
        var currentScale: CGFloat = 1.0
        var contentSignature: Int = 0
        var lastSearchQuery: String = ""
        var lastSearchNextToken: UInt = 0
        var lastSearchPrevToken: UInt = 0
        var searchCurrentIndex: Int = 0
        var searchMatchRanges: [NSRange] = []
        var lastHighlightedSearchRanges: [NSRange] = []
        private var firstResponderObserver: NSObjectProtocol?

        init(searchMatchCount: Binding<Int>, searchCurrentIndex: Binding<Int>) {
            _searchMatchCount = searchMatchCount
            searchCurrentIndexBinding = searchCurrentIndex
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
