import AppKit
import SwiftUI

/// 输出面板搜索框；回车仅消费按键，不结束编辑、不全选文字。
final class OutputFindTextField: NSTextField {
    var onFocusChanged: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isEditable = true
        isSelectable = true
        isBordered = false
        drawsBackground = true
        backgroundColor = OutputPanelStyle.commandFieldBackground
        textColor = OutputPanelStyle.commandFieldText
        font = OutputPanelStyle.commandFieldFont
        focusRingType = .none
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingTail
        cell?.wraps = false
        cell?.isScrollable = true
        cell?.truncatesLastVisibleLine = true
        placeholderAttributedString = NSAttributedString(
            string: L10n.Snippets.Output.find,
            attributes: [
                .foregroundColor: NSColor(white: 0.55, alpha: 1),
                .font: OutputPanelStyle.commandFieldFont,
            ]
        )
    }

    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused {
            onFocusChanged?(true)
            OutputPanelTextEditingCenter.shared.setActive(true)
        }
        return focused
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onFocusChanged?(false)
            OutputPanelTextEditingCenter.shared.setActive(false)
        }
        return resigned
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handlesReturn(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handlesReturn(_ event: NSEvent) -> Bool {
        guard isEnabled, isEditable else { return false }
        switch event.keyCode {
        case 36, 76:
            return true
        default:
            return false
        }
    }
}

/// 输出面板搜索框（NSTextField），字体与命令框一致；回车不结束编辑。
struct OutputFindField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> OutputFindTextField {
        let field = OutputFindTextField()
        field.delegate = context.coordinator
        field.onFocusChanged = { focused in
            context.coordinator.isFocused = focused
        }
        return field
    }

    func updateNSView(_ nsView: OutputFindTextField, context: Context) {
        context.coordinator.onTextChange = { text = $0 }
        context.coordinator.isFocusedBinding = $isFocused
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if isFocused, nsView.window?.firstResponder !== nsView.currentEditor() {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var onTextChange: (String) -> Void = { _ in }
        var isFocusedBinding: Binding<Bool>?
        var isFocused = false {
            didSet {
                guard isFocused != oldValue else { return }
                isFocusedBinding?.wrappedValue = isFocused
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            onTextChange(field.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            commandSelector == #selector(NSResponder.insertNewline(_:))
        }
    }
}
