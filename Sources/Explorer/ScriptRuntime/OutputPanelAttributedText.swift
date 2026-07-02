import AppKit
import Foundation
import SwiftUI

enum OutputPanelAttributedText {
    static let defaultStatusTabLocation: CGFloat = 600

    static func make(
        stdout: String,
        stderr: String,
        emptyPlaceholder: String,
        findText: String,
        statusTabLocation: CGFloat = defaultStatusTabLocation
    ) -> AttributedString {
        guard !stdout.isEmpty || !stderr.isEmpty else {
            var empty = AttributedString(emptyPlaceholder)
            empty.foregroundColor = OutputPanelStyle.placeholderColor
            return empty
        }
        return AttributedString(
            makeNSAttributedString(
                stdout: stdout,
                stderr: stderr,
                findText: findText,
                statusTabLocation: statusTabLocation
            )
        )
    }

    static func makeNSAttributedString(
        stdout: String,
        stderr: String,
        findText: String,
        statusTabLocation: CGFloat = defaultStatusTabLocation
    ) -> NSAttributedString {
        let baseFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let result = NSMutableAttributedString()
        for segment in OutputSessionFormatting.transcriptSegments(from: stdout) {
            let color = segment.isStderr ? OutputPanelStyle.stderrNSColor : OutputPanelStyle.stdoutNSColor
            let segmentAttr = NSMutableAttributedString(
                string: segment.text,
                attributes: [.foregroundColor: color, .font: baseFont]
            )
            if !segment.isStderr {
                applyPromptStyling(to: segmentAttr, statusTabLocation: statusTabLocation)
            }
            result.append(segmentAttr)
        }

        if !stderr.isEmpty {
            if result.length > 0 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
            }
            result.append(NSAttributedString(
                string: stderr,
                attributes: [.foregroundColor: OutputPanelStyle.stderrNSColor, .font: baseFont]
            ))
        }

        if !findText.isEmpty {
            applyFindHighlight(to: result, findText: findText)
        }

        return result
    }

    /// 面板宽度变化时，仅更新命令行状态图标的右对齐位置。
    static func refreshStatusTabLocations(in attr: NSMutableAttributedString, statusTabLocation: CGFloat) {
        let source = attr.string
        guard let regex = try? NSRegularExpression(pattern: #"([^\n]+) \$ ([^\n\t]+)\t([✓✗⊘])\n"#) else {
            return
        }

        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in regex.matches(in: source, range: fullRange) {
            applyPromptLineTabStyle(to: attr, lineRange: match.range, statusTabLocation: statusTabLocation)
        }
    }

    private static func applyPromptStyling(to attr: NSMutableAttributedString, statusTabLocation: CGFloat) {
        styleCompletedPromptLines(in: attr, statusTabLocation: statusTabLocation)
        styleIncompletePromptLines(in: attr)
    }

    private static func styleCompletedPromptLines(
        in attr: NSMutableAttributedString,
        statusTabLocation: CGFloat
    ) {
        let source = attr.string
        guard let regex = try? NSRegularExpression(pattern: #"([^\n]+) \$ ([^\n\t]+)\t([✓✗⊘])\n"#) else {
            return
        }

        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in regex.matches(in: source, range: fullRange) {
            guard match.numberOfRanges == 4 else { continue }
            colorMatchGroup(match.range(at: 1), color: OutputPanelStyle.promptPathNSColor, in: attr)
            colorMatchGroup(match.range(at: 2), color: OutputPanelStyle.promptCommandNSColor, in: attr)
            if let markerRange = Range(match.range(at: 3), in: source) {
                let marker = String(source[markerRange])
                colorMatchGroup(match.range(at: 3), color: statusColor(for: marker), in: attr)
            }
            applyPromptLineTabStyle(to: attr, lineRange: match.range, statusTabLocation: statusTabLocation)
        }
    }

    private static func styleIncompletePromptLines(in attr: NSMutableAttributedString) {
        let source = attr.string
        guard let regex = try? NSRegularExpression(pattern: #"([^\n]+) \$ ([^\n\t]+)\n"#) else {
            return
        }

        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in regex.matches(in: source, range: fullRange) {
            guard match.numberOfRanges == 3 else { continue }
            let line = (source as NSString).substring(with: match.range)
            guard !line.contains("\t") else { continue }
            colorMatchGroup(match.range(at: 1), color: OutputPanelStyle.promptPathNSColor, in: attr)
            colorMatchGroup(match.range(at: 2), color: OutputPanelStyle.promptCommandNSColor, in: attr)
        }
    }

    private static func applyPromptLineTabStyle(
        to attr: NSMutableAttributedString,
        lineRange: NSRange,
        statusTabLocation: CGFloat
    ) {
        let style = NSMutableParagraphStyle()
        style.tabStops = [
            NSTextTab(textAlignment: .right, location: statusTabLocation, options: [:])
        ]
        attr.addAttribute(.paragraphStyle, value: style, range: lineRange)
    }

    private static func statusColor(for marker: String) -> NSColor {
        switch marker {
        case "✓": return NSColor(red: 0.45, green: 0.82, blue: 0.52, alpha: 1)
        case "✗": return NSColor(red: 1.0, green: 0.55, blue: 0.55, alpha: 1)
        case "⊘": return NSColor(white: 0.62, alpha: 1)
        default: return OutputPanelStyle.stdoutNSColor
        }
    }

    private static func colorMatchGroup(
        _ nsRange: NSRange,
        color: NSColor,
        in attr: NSMutableAttributedString
    ) {
        guard nsRange.location != NSNotFound, nsRange.length > 0 else { return }
        attr.addAttribute(.foregroundColor, value: color, range: nsRange)
    }

    static func findMatchRanges(of query: String, in text: String) -> [NSRange] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let nsText = text as NSString
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.location < nsText.length {
            let found = nsText.range(of: trimmed, options: [.caseInsensitive], range: searchRange)
            if found.location == NSNotFound { break }
            ranges.append(found)
            let nextLocation = found.location + max(found.length, 1)
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }
        return ranges
    }

    private static func applyFindHighlight(to attr: NSMutableAttributedString, findText: String) {
        let highlight = OutputPanelStyle.findHighlightNSColor
        for range in findMatchRanges(of: findText, in: attr.string) {
            guard range.location != NSNotFound, NSMaxRange(range) <= attr.length else { continue }
            attr.addAttribute(.backgroundColor, value: highlight, range: range)
            attr.addAttribute(.foregroundColor, value: OutputPanelStyle.findHighlightForegroundNSColor, range: range)
        }
    }
}
