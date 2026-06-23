import AppKit
import SwiftUI

/// docx 富文本预览：NSTextView + scaleUnitSquare，缩放行为与 TextEdit / Markdown 预览一致。
struct OfficeRichTextPreview: NSViewRepresentable {
    let attributedText: NSAttributedString
    let wrapLines: Bool
    let zoomScale: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapLines
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        configureLayout(textView: textView, scrollView: scrollView, wrapLines: wrapLines)
        textView.textStorage?.setAttributedString(attributedText)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.currentScale = 1.0
        context.coordinator.contentSignature = 0
        applyScale(zoomScale, to: textView, context: context)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        scrollView.hasHorizontalScroller = !wrapLines
        configureLayout(textView: textView, scrollView: scrollView, wrapLines: wrapLines)

        let signature = attributedText.length ^ attributedText.string.hashValue
        if context.coordinator.contentSignature != signature {
            context.coordinator.contentSignature = signature
            textView.textStorage?.setAttributedString(attributedText)
            let current = context.coordinator.currentScale
            if abs(current - 1.0) > 0.0001 {
                textView.scaleUnitSquare(to: NSSize(width: 1.0 / current, height: 1.0 / current))
            }
            context.coordinator.currentScale = 1.0
            textView.scrollToBeginningOfDocument(nil)
        }

        applyScale(zoomScale, to: textView, context: context)
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
        weak var textView: NSTextView?
        var currentScale: CGFloat = 1.0
        var contentSignature: Int = 0
    }
}
