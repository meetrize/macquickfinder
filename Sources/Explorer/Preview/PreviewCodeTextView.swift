import AppKit

/// 只读代码预览文本视图，支持选区复制。
final class PreviewCodeTextView: NSTextView {
    var onInteractionStateChanged: (() -> Void)?

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

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        let text = (string as NSString).substring(with: range)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
