import AppKit
import Foundation

/// Markdown 预览 Mermaid 图：识别 ` ```mermaid ` 围栏块并替换为 `NSTextAttachment` 占位。
enum MarkdownPreviewMermaidBlock {
    struct Block: Equatable {
        let startLine: Int
        /// 闭合围栏行之后的首行索引（半开区间 `[startLine, endLine)`）。
        let endLine: Int
        let source: String
    }

    struct PendingRender: Equatable {
        let renderID: UUID
        let source: String
        let layoutWidth: CGFloat
    }

    struct CachedRender {
        let image: NSImage
        let displaySize: NSSize
    }

    static func cacheKey(source: String, isDark: Bool) -> String {
        "\(isDark ? "dark" : "light")|\(source)"
    }

    private static let openFenceRegex = try? NSRegularExpression(
        pattern: #"^\s*```\s*mermaid\s*$"#,
        options: [.caseInsensitive]
    )

    static func isMermaidOpenFence(_ line: String) -> Bool {
        guard let openFenceRegex else { return false }
        let range = NSRange(location: 0, length: (line as NSString).length)
        return openFenceRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    /// 扫描行数组，跳过普通围栏代码块，仅提取顶层 `mermaid` 块。
    static func findBlocks(in lines: [String]) -> [Block] {
        var blocks: [Block] = []
        var index = 0

        while index < lines.count {
            if isMermaidOpenFence(lines[index]) {
                let start = index
                index += 1
                let contentStart = index
                while index < lines.count, !MarkdownPreviewTableLayout.isFenceLine(lines[index]) {
                    index += 1
                }
                guard index < lines.count else { break }

                let source = lines[contentStart..<index].joined(separator: "\n")
                blocks.append(Block(startLine: start, endLine: index + 1, source: source))
                index += 1
                continue
            }

            if MarkdownPreviewTableLayout.isFenceLine(lines[index]) {
                index += 1
                while index < lines.count, !MarkdownPreviewTableLayout.isFenceLine(lines[index]) {
                    index += 1
                }
                if index < lines.count {
                    index += 1
                }
                continue
            }

            index += 1
        }

        return blocks
    }

    /// 将 Mermaid 围栏块替换为附件占位，并返回待异步渲染的任务列表（文档顺序）。
    static func apply(
        in rendered: NSMutableAttributedString,
        layoutWidth: CGFloat?,
        renderingLabel: String,
        isDark: Bool,
        cachedRenders: [String: CachedRender]
    ) -> [PendingRender] {
        let lines = rendered.string.components(separatedBy: "\n")
        let blocks = findBlocks(in: lines)
        guard !blocks.isEmpty else { return [] }

        let contentWidth = max(layoutWidth ?? 400, 160)
        var lineMap = lineRanges(in: rendered.string as NSString)
        var pending: [PendingRender] = []

        for block in blocks.reversed() {
            guard block.startLine < lineMap.count, block.endLine > 0, block.endLine - 1 < lineMap.count else {
                continue
            }

            let blockStart = lineMap[block.startLine].location
            let lastLineRange = lineMap[block.endLine - 1]
            let blockRange = NSRange(
                location: blockStart,
                length: lastLineRange.location + lastLineRange.length - blockStart
            )

            let renderID = UUID()
            let attachment = MarkdownMermaidAttachment(
                renderID: renderID,
                source: block.source,
                layoutWidth: contentWidth,
                isDark: isDark
            )
            let cacheKey = cacheKey(source: block.source, isDark: isDark)
            if let cached = cachedRenders[cacheKey] {
                attachment.image = cached.image
                attachment.bounds = attachmentBounds(for: cached.displaySize)
            } else {
                attachment.image = placeholderImage(
                    width: contentWidth,
                    label: renderingLabel
                )
                attachment.bounds = attachmentBounds(for: attachment.image?.size ?? NSSize(width: contentWidth, height: 32))
                pending.append(PendingRender(renderID: renderID, source: block.source, layoutWidth: contentWidth))
            }
            let replacement = NSAttributedString(attachment: attachment)
            rendered.replaceCharacters(in: blockRange, with: replacement)

            lineMap = lineRanges(in: rendered.string as NSString)
        }

        return pending.reversed()
    }

    static func makeFailedPlaceholder(width: CGFloat, label: String) -> NSImage {
        placeholderImage(width: width, label: label, isError: true)
    }

    // MARK: - Private

    private static func lineRanges(in text: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var offset = 0
        for line in text.components(separatedBy: "\n") {
            let length = (line as NSString).length
            ranges.append(NSRange(location: offset, length: length))
            offset += length + 1
        }
        return ranges
    }

    private static func placeholderImage(width: CGFloat, label: String, isError: Bool = false) -> NSImage {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let text = label as NSString
        let textSize = text.size(withAttributes: [.font: font])
        let height = max(32, textSize.height + 20)
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()

        let background = isError
            ? NSColor.systemRed.withAlphaComponent(0.08)
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.12)
        background.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 6, yRadius: 6).fill()

        let foreground = isError ? NSColor.systemRed : NSColor.secondaryLabelColor
        let drawPoint = NSPoint(x: 12, y: (height - textSize.height) / 2)
        text.draw(at: drawPoint, withAttributes: [.font: font, .foregroundColor: foreground])
        image.unlockFocus()
        return image
    }

    static func attachmentBounds(for size: NSSize) -> CGRect {
        CGRect(x: 0, y: -size.height, width: size.width, height: size.height)
    }
}

final class MarkdownMermaidAttachment: NSTextAttachment {
    let renderID: UUID
    let source: String
    let layoutWidth: CGFloat
    let isDark: Bool

    init(renderID: UUID, source: String, layoutWidth: CGFloat, isDark: Bool) {
        self.renderID = renderID
        self.source = source
        self.layoutWidth = layoutWidth
        self.isDark = isDark
        super.init(data: nil, ofType: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
