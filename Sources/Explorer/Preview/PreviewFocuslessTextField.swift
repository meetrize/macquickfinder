import AppKit
import SwiftUI

/// 预览顶栏文本输入框：可编辑，但不显示窗口激活时的键盘聚焦蓝框。
struct PreviewFocuslessTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var width: CGFloat?
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = PreviewToolbarNSTextField()
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        field.placeholderString = placeholder
        field.stringValue = text
        field.onSubmit = { context.coordinator.didSubmit() }
        if let width {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        (nsView as? PreviewToolbarNSTextField)?.onSubmit = { context.coordinator.didSubmit() }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func didSubmit() {
            onSubmit?()
        }
    }
}

private final class PreviewToolbarNSTextField: NSTextField {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            onSubmit?()
            return
        default:
            break
        }
        super.keyDown(with: event)
    }
}
