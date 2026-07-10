import AppKit
import CoreText
import Foundation

/// 为 `.ttf` / `.otf` 生成简易字形样张缩略图（Quick Look 效果一般）。
enum FontPreviewThumbnailRenderer {
    static func renderSampleImage(for url: URL, cellSize: CGFloat) -> NSImage? {
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        guard let descriptor = descriptors?.first else { return nil }

        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        defer {
            if registered {
                CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        guard registered else { return nil }

        let pointSize = max(11, cellSize * 0.34)
        let ctFont = CTFontCreateWithFontDescriptor(descriptor, pointSize, nil)
        guard let postScriptName = CTFontCopyPostScriptName(ctFont) as String?,
              let font = NSFont(name: postScriptName, size: pointSize) else {
            return nil
        }

        let text = "Aa" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        let attributed = NSAttributedString(string: text as String, attributes: attributes)
        let textSize = attributed.size()
        let canvas = NSSize(
            width: max(24, ceil(textSize.width) + 8),
            height: max(24, ceil(textSize.height) + 6)
        )

        let image = NSImage(size: canvas)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: canvas).fill()
        attributed.draw(at: NSPoint(x: 4, y: 3))
        image.unlockFocus()
        return image
    }
}
