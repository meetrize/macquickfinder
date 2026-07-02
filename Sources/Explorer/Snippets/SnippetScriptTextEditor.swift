import AppKit
import SwiftUI

/// 可编辑脚本文本框，基于 `NSTextView` 以支持 Cmd+Z/C/X/V/A 等标准编辑快捷键。
struct SnippetScriptTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var pendingInsert: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, pendingInsert: $pendingInsert)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = SnippetScriptTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 6
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.backgroundColor = .textBackgroundColor
        textView.delegate = context.coordinator
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if context.coordinator.isUpdatingFromView {
            context.coordinator.applyPendingInsertIfNeeded(on: textView)
            return
        }

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            let clampedLocation = min(selectedRange.location, length)
            let clampedLength = min(selectedRange.length, max(0, length - clampedLocation))
            textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
        }

        context.coordinator.applyPendingInsertIfNeeded(on: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var pendingInsert: String?
        weak var textView: NSTextView?
        var isUpdatingFromView = false

        init(text: Binding<String>, pendingInsert: Binding<String?>) {
            _text = text
            _pendingInsert = pendingInsert
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdatingFromView = true
            text = textView.string
            isUpdatingFromView = false
        }

        func applyPendingInsertIfNeeded(on textView: NSTextView) {
            guard let token = pendingInsert, !token.isEmpty else { return }
            pendingInsert = nil

            textView.window?.makeFirstResponder(textView)
            textView.insertText(token, replacementRange: textView.selectedRange())

            isUpdatingFromView = true
            text = textView.string
            isUpdatingFromView = false
        }
    }
}

private final class SnippetScriptTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "a":
            selectAll(nil)
            return true
        case "c":
            copy(nil)
            return true
        case "x":
            cut(nil)
            return true
        case "v":
            paste(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
