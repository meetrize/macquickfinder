import AppKit
import SwiftUI

/// 输出面板底部多行命令编辑器（内联展开，非浮层）。
struct OutputCommandMultilineField: NSViewRepresentable {
    @Binding var text: String
    var isEnabled: Bool
    var refocusToken: UInt = 0
    var colorScheme: OutputPanelColorScheme = .dark
    var onFocusChange: (Bool) -> Void
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onFocusChange: onFocusChange, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        OutputPanelScrollerStyle.installVerticalOverlayScroller(on: scrollView)

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.font = OutputPanelStyle.commandFieldFont
        textView.textColor = OutputPanelStyle.commandFieldText
        textView.insertionPointColor = OutputPanelStyle.commandFieldText
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.installFocusObservers(for: textView)
        context.coordinator.installKeyMonitor()
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        textView.isEditable = isEnabled
        if context.coordinator.lastColorScheme != colorScheme {
            context.coordinator.lastColorScheme = colorScheme
            OutputPanelStyle.applyCommandFieldAppearance(to: textView)
            scrollView.verticalScroller?.needsDisplay = true
        }
        context.coordinator.syncTextIfNeeded(text)
        if context.coordinator.lastRefocusToken != refocusToken {
            context.coordinator.lastRefocusToken = refocusToken
            context.coordinator.focusEditor(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let onFocusChange: (Bool) -> Void
        let onSubmit: () -> Void
        weak var textView: NSTextView?
        var lastRefocusToken: UInt = 0
        var lastColorScheme: OutputPanelColorScheme?
        private var suppressSync = false
        private var selectionObserver: NSObjectProtocol?
        private var keyMonitor: Any?

        init(text: Binding<String>, onFocusChange: @escaping (Bool) -> Void, onSubmit: @escaping () -> Void) {
            _text = text
            self.onFocusChange = onFocusChange
            self.onSubmit = onSubmit
        }

        deinit {
            if let selectionObserver {
                NotificationCenter.default.removeObserver(selectionObserver)
            }
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
        }

        func installFocusObservers(for textView: NSTextView) {
            selectionObserver = NotificationCenter.default.addObserver(
                forName: NSTextView.didChangeSelectionNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                self?.syncFocusState(for: textView)
            }
        }

        func installKeyMonitor() {
            guard keyMonitor == nil else { return }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let textView = self.textView,
                      textView.window?.firstResponder === textView else {
                    return event
                }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags.contains(.command),
                   event.keyCode == 36 || event.keyCode == 76 {
                    self.onSubmit()
                    return nil
                }
                return event
            }
        }

        private func syncFocusState(for textView: NSTextView) {
            let focused = textView.window?.firstResponder === textView
            onFocusChange(focused)
            Task { @MainActor in
                OutputPanelTextEditingCenter.shared.setActive(focused)
            }
        }

        func focusEditor(_ textView: NSTextView) {
            DispatchQueue.main.async { [weak self] in
                guard let window = textView.window else { return }
                window.makeFirstResponder(textView)
                self?.syncFocusState(for: textView)
            }
        }

        func syncTextIfNeeded(_ newText: String) {
            guard !suppressSync, textView?.string != newText else { return }
            textView?.string = newText
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            suppressSync = true
            text = textView.string
            suppressSync = false
        }
    }
}
