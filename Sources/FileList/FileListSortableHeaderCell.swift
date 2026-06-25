import AppKit

final class FileListSortableHeaderCell: NSTableHeaderCell {
    var baseTitle: String
    var sortIndicator: String?

    init(title: String) {
        self.baseTitle = title
        self.sortIndicator = nil
        super.init(textCell: title)
    }

    required init(coder: NSCoder) {
        self.baseTitle = ""
        self.sortIndicator = nil
        super.init(coder: coder)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let horizontalInset: CGFloat = 6
        let spacing: CGFloat = 6
        let contentRect = cellFrame.insetBy(dx: horizontalInset, dy: 0)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        if let indicator = sortIndicator, !indicator.isEmpty {
            let indicatorAttributes: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let indicatorSize = (indicator as NSString).size(withAttributes: indicatorAttributes)
            let indicatorRect = NSRect(
                x: contentRect.maxX - indicatorSize.width,
                y: contentRect.midY - indicatorSize.height / 2,
                width: indicatorSize.width,
                height: indicatorSize.height
            )
            let titleRect = NSRect(
                x: contentRect.minX,
                y: contentRect.minY,
                width: max(0, contentRect.width - indicatorSize.width - spacing),
                height: contentRect.height
            )
            (baseTitle as NSString).draw(
                with: titleRect,
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: titleAttributes
            )
            (indicator as NSString).draw(in: indicatorRect, withAttributes: indicatorAttributes)
            return
        }

        (baseTitle as NSString).draw(
            with: contentRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: titleAttributes
        )
    }
}
