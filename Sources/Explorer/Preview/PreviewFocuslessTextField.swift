import AppKit
import SwiftUI

/// 预览顶栏文本输入框：可编辑，但不显示窗口激活时的键盘聚焦蓝框。
struct PreviewFocuslessTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var width: CGFloat?
    var isInline: Bool = false
    var isFocused: Binding<Bool>?
    var acceptsTabNavigation: Bool = false
    var onSubmit: (() -> Void)?
    var onShiftSubmit: (() -> Void)?
    var onEscape: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isFocused: isFocused,
            acceptsTabNavigation: acceptsTabNavigation,
            onSubmit: onSubmit,
            onShiftSubmit: onShiftSubmit,
            onEscape: onEscape
        )
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = PreviewToolbarNSTextField()
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.placeholderString = placeholder
        field.stringValue = text
        field.onSubmit = { context.coordinator.didSubmit(forward: true) }
        field.onShiftSubmit = { context.coordinator.didSubmit(forward: false) }
        field.onEscape = { context.coordinator.didEscape() }
        field.acceptsSearchKeyboardShortcuts = acceptsTabNavigation
        field.onFocusChanged = { focused in
            context.coordinator.isFocused = focused
        }
        applyStyle(to: field)
        if let width {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocusedBinding = isFocused
        context.coordinator.acceptsTabNavigation = acceptsTabNavigation
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onShiftSubmit = onShiftSubmit
        context.coordinator.onEscape = onEscape
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        applyStyle(to: nsView)
        guard let field = nsView as? PreviewToolbarNSTextField else { return }
        field.onSubmit = { context.coordinator.didSubmit(forward: true) }
        field.onShiftSubmit = { context.coordinator.didSubmit(forward: false) }
        field.onEscape = { context.coordinator.didEscape() }
        field.acceptsSearchKeyboardShortcuts = acceptsTabNavigation
        field.onFocusChanged = { focused in
            context.coordinator.isFocused = focused
        }

        if let isFocusedBinding = isFocused {
            if isFocusedBinding.wrappedValue,
               nsView.window?.firstResponder !== nsView.currentEditor() {
                nsView.window?.makeFirstResponder(nsView)
            } else if !isFocusedBinding.wrappedValue {
                let firstResponder = nsView.window?.firstResponder
                if firstResponder === nsView.currentEditor() || firstResponder === nsView {
                    nsView.window?.makeFirstResponder(nil)
                }
            }
        }
    }

    private func applyStyle(to field: NSTextField) {
        if isInline {
            field.isBordered = false
            field.drawsBackground = false
            field.backgroundColor = .clear
            field.bezelStyle = .roundedBezel
            field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            field.lineBreakMode = .byTruncatingTail
            field.cell?.truncatesLastVisibleLine = true
        } else {
            field.isBordered = true
            field.drawsBackground = true
            field.bezelStyle = .roundedBezel
            field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var isFocusedBinding: Binding<Bool>?
        var acceptsTabNavigation: Bool
        var onSubmit: (() -> Void)?
        var onShiftSubmit: (() -> Void)?
        var onEscape: (() -> Void)?
        var isFocused = false {
            didSet {
                guard isFocused != oldValue else { return }
                isFocusedBinding?.wrappedValue = isFocused
            }
        }

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>?,
            acceptsTabNavigation: Bool,
            onSubmit: (() -> Void)?,
            onShiftSubmit: (() -> Void)?,
            onEscape: (() -> Void)?
        ) {
            self.text = text
            self.isFocusedBinding = isFocused
            self.acceptsTabNavigation = acceptsTabNavigation
            self.onSubmit = onSubmit
            self.onShiftSubmit = onShiftSubmit
            self.onEscape = onEscape
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                didSubmit(forward: !NSEvent.modifierFlags.contains(.shift))
                return true
            }
            if acceptsTabNavigation, commandSelector == #selector(NSResponder.insertTab(_:)) {
                didSubmit(forward: true)
                return true
            }
            if acceptsTabNavigation, commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                didSubmit(forward: false)
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                guard onEscape != nil else { return false }
                didEscape()
                return true
            }
            return false
        }

        func didSubmit(forward: Bool) {
            if forward {
                onSubmit?()
            } else if onShiftSubmit != nil {
                onShiftSubmit?()
            }
        }

        func didEscape() {
            onEscape?()
            isFocused = false
        }
    }
}

private final class PreviewToolbarNSTextField: NSTextField {
    var onSubmit: (() -> Void)?
    var onShiftSubmit: (() -> Void)?
    var onEscape: (() -> Void)?
    var acceptsSearchKeyboardShortcuts = false
    var onFocusChanged: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused { onFocusChanged?(true) }
        return focused
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChanged?(false) }
        return resigned
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let action = PreviewTextSearchKeyboard.action(for: event) {
            switch action {
            case .findNext:
                guard acceptsSearchKeyboardShortcuts else { break }
                onSubmit?()
                return true
            case .findPrevious:
                guard acceptsSearchKeyboardShortcuts else { break }
                onShiftSubmit?()
                return true
            case .clear:
                guard onEscape != nil else { break }
                onEscape?()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if acceptsSearchKeyboardShortcuts, let action = PreviewTextSearchKeyboard.action(for: event) {
            switch action {
            case .findNext:
                onSubmit?()
                return
            case .findPrevious:
                onShiftSubmit?()
                return
            case .clear:
                onEscape?()
                return
            }
        }

        switch event.keyCode {
        case 36, 76:
            if event.modifierFlags.contains(.shift), onShiftSubmit != nil {
                onShiftSubmit?()
            } else {
                onSubmit?()
            }
            return
        case 53 where onEscape != nil:
            onEscape?()
            return
        default:
            break
        }
        super.keyDown(with: event)
    }
}
