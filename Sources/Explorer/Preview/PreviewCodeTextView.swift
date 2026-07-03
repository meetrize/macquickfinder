import AppKit

/// 文本预览视图，支持只读选区/复制与编辑模式下的剪切/粘贴。
final class PreviewCodeTextView: NSTextView {
    var onInteractionStateChanged: (() -> Void)?
    var onTextContentChanged: (() -> Void)?
    var allowsEditing = false

    override func didChangeText() {
        super.didChangeText()
        guard allowsEditing else { return }
        onTextContentChanged?()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onInteractionStateChanged?() }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onInteractionStateChanged?() }
        return resigned
    }

    override func selectAll(_ sender: Any?) {
        guard !string.isEmpty else { return }
        setSelectedRange(NSRange(location: 0, length: (string as NSString).length))
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        if allowsEditing {
            super.copy(sender)
            return
        }
        let text = (string as NSString).substring(with: range)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    override func cut(_ sender: Any?) {
        guard allowsEditing else { return }
        super.cut(sender)
    }

    override func paste(_ sender: Any?) {
        guard allowsEditing else { return }
        super.paste(sender)
    }
}
