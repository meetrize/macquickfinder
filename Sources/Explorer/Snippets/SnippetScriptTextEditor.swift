import AppKit
import SwiftUI

/// 把变量 token 直接插入脚本 `NSTextView` 当前（或失焦前锚定的）光标位置。
@MainActor
final class SnippetScriptInsertBridge: ObservableObject {
    weak var textView: SnippetScriptTextView?

    func insert(_ token: String) {
        guard !token.isEmpty, let textView else { return }

        let length = (textView.string as NSString).length
        let preferred = textView.anchoredSelectedRange
        let location = min(max(0, preferred.location), length)
        let rangeLength = min(max(0, preferred.length), length - location)
        let insertionRange = NSRange(location: location, length: rangeLength)

        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(insertionRange)

        if textView.shouldChangeText(in: insertionRange, replacementString: token) {
            textView.replaceCharacters(in: insertionRange, with: token)
            textView.didChangeText()
        }

        let newLocation = location + (token as NSString).length
        let newSelection = NSRange(location: newLocation, length: 0)
        textView.setSelectedRange(newSelection)
        textView.anchoredSelectedRange = newSelection
    }
}

/// 可编辑脚本文本框，基于 `NSTextView` 以支持 Cmd+Z/C/X/V/A 等标准编辑快捷键。
struct SnippetScriptTextEditor: NSViewRepresentable {
    @Binding var text: String
    var insertBridge: SnippetScriptInsertBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
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
        textView.anchoredSelectedRange = textView.selectedRange()

        scrollView.documentView = textView
        context.coordinator.textView = textView
        insertBridge.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? SnippetScriptTextView else { return }
        insertBridge.textView = textView

        if context.coordinator.isUpdatingFromView { return }

        if textView.string != text {
            let selectedRange = textView.anchoredSelectedRange
            textView.string = text
            let length = (text as NSString).length
            let clampedLocation = min(selectedRange.location, length)
            let clampedLength = min(selectedRange.length, max(0, length - clampedLocation))
            let clamped = NSRange(location: clampedLocation, length: clampedLength)
            textView.setSelectedRange(clamped)
            textView.anchoredSelectedRange = clamped
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        var isUpdatingFromView = false

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? SnippetScriptTextView else { return }
            textView.anchoredSelectedRange = textView.selectedRange()
            isUpdatingFromView = true
            text.wrappedValue = textView.string
            isUpdatingFromView = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? SnippetScriptTextView else { return }
            if textView.window?.firstResponder === textView {
                textView.anchoredSelectedRange = textView.selectedRange()
            }
        }
    }
}

final class SnippetScriptTextView: NSTextView {
    /// 失焦前锚定的选区，供变量按钮插入使用。
    var anchoredSelectedRange: NSRange = NSRange(location: 0, length: 0)

    override func setSelectedRange(_ charRange: NSRange) {
        super.setSelectedRange(charRange)
        anchorSelectionIfFocused()
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        if !stillSelecting {
            anchorSelectionIfFocused()
        }
    }

    override func resignFirstResponder() -> Bool {
        anchoredSelectedRange = selectedRange()
        return super.resignFirstResponder()
    }

    private func anchorSelectionIfFocused() {
        guard window?.firstResponder === self else { return }
        anchoredSelectedRange = selectedRange()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 仅在脚本文本框本身为第一响应者时拦截 ⌘A/C/X/V，避免抢走弹窗内其他输入框的粘贴等快捷键。
        guard window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }

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
