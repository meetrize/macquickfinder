import AppKit
import PDFKit

/// 只读 PDF 预览视图，支持点击获焦、全选文本与复制。
final class PreviewPDFView: PDFView {
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

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func selectAll(_ sender: Any?) {
        guard let document else { return }
        var fullSelection: PDFSelection?
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let charCount = page.numberOfCharacters
            guard charCount > 0,
                  let pageSelection = page.selection(for: NSRange(location: 0, length: charCount))
            else { continue }
            if let fullSelection {
                fullSelection.add(pageSelection)
            } else {
                fullSelection = pageSelection
            }
        }
        guard let fullSelection, let text = fullSelection.string, !text.isEmpty else { return }
        currentSelection = fullSelection
    }

    override func copy(_ sender: Any?) {
        guard let text = currentSelection?.string, !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
