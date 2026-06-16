import AppKit

/// 单行绘制带省略号的 attributed 文本；NSTextField 对 attributedString 的截断不可靠。
final class FileListTruncatingLabel: NSView {
    var attributedString: NSAttributedString = NSAttributedString() {
        didSet {
            guard oldValue != attributedString else { return }
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard attributedString.length > 0, bounds.width > 0 else { return }
        
        let maxSize = NSSize(width: bounds.width, height: .greatestFiniteMagnitude)
        let textHeight = ceil(
            attributedString.boundingRect(
                with: maxSize,
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).height
        )
        let drawHeight = min(textHeight, bounds.height)
        let y = bounds.minY + max(0, (bounds.height - drawHeight) / 2)
        let rect = NSRect(x: bounds.minX, y: y, width: bounds.width, height: drawHeight)
        
        attributedString.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
            context: nil
        )
    }
}
