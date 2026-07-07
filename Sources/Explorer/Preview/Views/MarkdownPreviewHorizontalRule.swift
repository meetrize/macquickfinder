import AppKit
import Foundation

/// Markdown 预览横线：识别独立 `---` / `***` / `___` 行并渲染为分隔线。
enum MarkdownPreviewHorizontalRule {
    private static let markerRegex = try? NSRegularExpression(
        pattern: #"^[\t ]*(-{3,}|\*{3,}|_{3,})[\t ]*$"#,
        options: []
    )

    static func isHorizontalRuleLine(_ line: String) -> Bool {
        guard let markerRegex else { return false }
        let range = NSRange(location: 0, length: (line as NSString).length)
        return markerRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    static func frontMatterLineIndices(in lines: [String]) -> Set<Int> {
        guard lines.first.map(isHorizontalRuleLine) == true else { return [] }

        var indices: Set<Int> = [0]
        for index in 1..<lines.count {
            if isHorizontalRuleLine(lines[index]) {
                indices.insert(index)
                return indices
            }
            indices.insert(index)
        }
        return [0]
    }

    static func horizontalRuleLineIndices(
        in lines: [String],
        skipLineIndices: Set<Int> = []
    ) -> [Int] {
        var indices: [Int] = []
        var inFence = false
        let frontMatter = frontMatterLineIndices(in: lines)

        for (index, line) in lines.enumerated() {
            if MarkdownPreviewTableLayout.isFenceLine(line) {
                inFence.toggle()
                continue
            }
            if inFence || frontMatter.contains(index) || skipLineIndices.contains(index) {
                continue
            }
            if isHorizontalRuleLine(line) {
                indices.append(index)
            }
        }
        return indices
    }

    static func renderLine(
        indent: String,
        availableWidth: CGFloat?,
        font: NSFont
    ) -> String {
        let glyph = "─"
        let glyphWidth = max(MarkdownPreviewTableLayout.measuredWidth(glyph, font: font), 1)
        let indentWidth = MarkdownPreviewTableLayout.measuredWidth(indent, font: font)
        let targetWidth = max((availableWidth ?? 480) - indentWidth, glyphWidth * 12)
        let count = max(12, Int(floor(targetWidth / glyphWidth)))
        return indent + String(repeating: glyph, count: count)
    }

    static func leadingIndent(_ line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }
}
