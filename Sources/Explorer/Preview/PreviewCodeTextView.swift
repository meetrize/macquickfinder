import AppKit

/// 只读文本预览视图，支持点击获焦、全选与复制。
final class PreviewCodeTextView: NSTextView {
    var onInteractionStateChanged: (() -> Void)?

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
        let text = (string as NSString).substring(with: range)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
