import AppKit

/// Mermaid 附件是否处于 Markdown 预览可视区域（含预加载边距）。
enum MarkdownPreviewMermaidVisibility {
    static let preloadMargin: CGFloat = 320

    static func isAttachmentVisible(
        renderID: UUID,
        in textView: NSTextView,
        scrollView: NSScrollView,
        preloadMargin: CGFloat = preloadMargin
    ) -> Bool {
        guard let storage = textView.textStorage,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return true
        }

        var attachmentRange: NSRange?
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
            guard let attachment = value as? MarkdownMermaidAttachment,
                  attachment.renderID == renderID else { return }
            attachmentRange = range
            stop.pointee = true
        }
        guard let range = attachmentRange else { return false }

        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var attachmentRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let origin = textView.textContainerOrigin
        attachmentRect.origin.x += origin.x
        attachmentRect.origin.y += origin.y

        let visibleRect = scrollView.contentView.bounds.insetBy(dx: 0, dy: -preloadMargin)
        return rectsIntersect(attachmentRect, visible: visibleRect)
    }

    static func rectsIntersect(_ attachment: CGRect, visible: CGRect) -> Bool {
        guard !attachment.isNull, !visible.isNull else { return false }
        return attachment.intersects(visible)
    }
}
