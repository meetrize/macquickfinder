import AppKit

/// 代码预览左侧行号标尺，与 `NSTextView` 滚动同步。
final class CodePreviewLineNumberRulerView: NSRulerView {
    weak var textView: NSTextView? {
        didSet { needsDisplay = true }
    }

    private var scrollObserver: NSObjectProtocol?

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        updateRuleThickness(for: textView.string)

        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // 不调用 super，避免 NSRulerView 默认绘制不透明底色。
        drawHashMarksAndLabels(in: dirtyRect)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
    }

    func updateRuleThickness(for text: String) {
        let lineCount = max(1, text.components(separatedBy: "\n").count)
        let digits = String(lineCount).count
        ruleThickness = max(32, CGFloat(digits) * 8 + 18)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView else { return }

        let fillRect = bounds.intersection(rect)
        guard !fillRect.isNull, fillRect.width > 0, fillRect.height > 0 else { return }

        NSColor.quaternaryLabelColor.withAlphaComponent(0.12).setFill()
        fillRect.fill()

        let separator = NSBezierPath()
        NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
        separator.move(to: NSPoint(x: bounds.maxX - 0.5, y: fillRect.minY))
        separator.line(to: NSPoint(x: bounds.maxX - 0.5, y: fillRect.maxY))
        separator.lineWidth = 1
        separator.stroke()

        let visibleRect = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard glyphRange.length > 0 else { return }

        let fontSize = textView.font?.pointSize ?? NSFont.systemFontSize
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let nsText = textView.string as NSString
        let labelClipRect = bounds.intersection(fillRect)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { fragmentRect, _, _, glyphRange, _ in
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            guard charRange.location != NSNotFound else { return }
            guard Self.isLogicalLineStart(location: charRange.location, in: nsText) else { return }

            let lineNumber = Self.lineNumber(at: charRange.location, in: nsText)
            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: attributes)
            let fragmentInRuler = textView.convert(fragmentRect, to: self)
            let x = self.ruleThickness - labelSize.width - 8
            let drawY = fragmentInRuler.midY - labelSize.height / 2
            let labelRect = NSRect(x: x, y: drawY, width: labelSize.width, height: labelSize.height)
            // 行号须完整落在可见区域内；边缘半行不绘制，避免钳制后与相邻行号重叠。
            guard labelClipRect.contains(labelRect) else { return }
            label.draw(at: NSPoint(x: x, y: drawY), withAttributes: attributes)
        }
    }

    private static func isLogicalLineStart(location: Int, in text: NSString) -> Bool {
        location == 0 || text.character(at: location - 1) == unichar(0x0A)
    }

    private static func lineNumber(at location: Int, in text: NSString) -> Int {
        guard location > 0 else { return 1 }
        var count = 1
        for index in 0..<location where text.character(at: index) == unichar(0x0A) {
            count += 1
        }
        return count
    }
}
