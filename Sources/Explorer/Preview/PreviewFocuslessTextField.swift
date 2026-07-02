import AppKit
import SwiftUI

/// 预览顶栏文本输入框：可编辑，但不显示窗口激活时的键盘聚焦蓝框。
struct PreviewFocuslessTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var width: CGFloat?
    var isInline: Bool = false
    var onSubmit: (() -> Void)?
    var onShiftSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, onShiftSubmit: onShiftSubmit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = PreviewToolbarNSTextField()
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.placeholderString = placeholder
        field.stringValue = text
        field.onSubmit = { context.coordinator.didSubmit(forward: true) }
        field.onShiftSubmit = { context.coordinator.didSubmit(forward: false) }
        applyStyle(to: field)
        if let width {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onShiftSubmit = onShiftSubmit
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        applyStyle(to: nsView)
        guard let field = nsView as? PreviewToolbarNSTextField else { return }
        field.onSubmit = { context.coordinator.didSubmit(forward: true) }
        field.onShiftSubmit = { context.coordinator.didSubmit(forward: false) }
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
        var onSubmit: (() -> Void)?
        var onShiftSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?, onShiftSubmit: (() -> Void)?) {
            self.text = text
            self.onSubmit = onSubmit
            self.onShiftSubmit = onShiftSubmit
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
            return false
        }

        func didSubmit(forward: Bool) {
            if forward {
                onSubmit?()
            } else if onShiftSubmit != nil {
                onShiftSubmit?()
            }
        }
    }
}

private final class PreviewToolbarNSTextField: NSTextField {
    var onSubmit: (() -> Void)?
    var onShiftSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            if event.modifierFlags.contains(.shift), onShiftSubmit != nil {
                onShiftSubmit?()
            } else {
                onSubmit?()
            }
            return
        default:
            break
        }
        super.keyDown(with: event)
    }
}
