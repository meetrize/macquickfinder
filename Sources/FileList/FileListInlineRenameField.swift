import AppKit

/// 文件列表内联重命名输入框：Enter 提交、Esc 取消，聚焦时高亮文件名（不含后缀）。
final class FileListInlineRenameField: NSTextField {
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    
    private var cancelledByEscape = false
    var suppressEndEditingCommit = false
    private var widthConstraint: NSLayoutConstraint?
    private(set) var maxLayoutWidth: CGFloat = 0
    
    private static let horizontalBezelPadding: CGFloat = 16
    private static let minFieldWidth: CGFloat = 40
    
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
        isBordered = true
        isBezeled = true
        bezelStyle = .roundedBezel
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        focusRingType = .exterior
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingTail
        cell?.wraps = false
        cell?.isScrollable = true
        delegate = self
    }
    
    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused {
            cancelledByEscape = false
            selectBaseName()
        }
        return focused
    }
    
    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.rightMouseDown(with: event)
    }
    
    func selectBaseName() {
        guard let editor = currentEditor() else { return }
        let name = stringValue as NSString
        let ext = name.pathExtension
        if !ext.isEmpty, name.length > ext.count + 1 {
            editor.selectedRange = NSRange(location: 0, length: name.length - ext.count - 1)
        } else {
            editor.selectAll(nil)
        }
    }
    
    /// 按文本宽度收紧输入框；仅当文件名超出可用列宽时才扩至列宽。
    func updateLayoutWidth(maxAvailableWidth: CGFloat) {
        maxLayoutWidth = max(0, maxAvailableWidth)
        let font = self.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let textWidth = ceil((stringValue as NSString).size(withAttributes: [.font: font]).width)
        let idealWidth = textWidth + Self.horizontalBezelPadding
        let cappedWidth = min(idealWidth, maxLayoutWidth)
        let width = max(Self.minFieldWidth, cappedWidth)
        
        if let widthConstraint {
            widthConstraint.constant = width
        } else {
            let constraint = widthAnchor.constraint(equalToConstant: width)
            constraint.priority = .required
            constraint.isActive = true
            widthConstraint = constraint
        }
    }
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        guard maxLayoutWidth > 0 else { return }
        updateLayoutWidth(maxAvailableWidth: maxLayoutWidth)
    }
}

extension FileListInlineRenameField: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            suppressEndEditingCommit = true
            onCommit?(stringValue)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelledByEscape = true
            onCancel?()
            return true
        }
        return false
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if suppressEndEditingCommit {
            suppressEndEditingCommit = false
            return
        }
        guard !cancelledByEscape else {
            cancelledByEscape = false
            return
        }
        onCommit?(stringValue)
    }
}
