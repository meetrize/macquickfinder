import AppKit
import Foundation
import SwiftUI

enum OutputPanelAttributedText {
    static func make(
        stdout: String,
        stderr: String,
        emptyPlaceholder: String,
        findText: String
    ) -> AttributedString {
        guard !stdout.isEmpty || !stderr.isEmpty else {
            var empty = AttributedString(emptyPlaceholder)
            empty.foregroundColor = OutputPanelStyle.placeholderColor
            return empty
        }
        return AttributedString(makeNSAttributedString(stdout: stdout, stderr: stderr, findText: findText))
    }

    static func makeNSAttributedString(
        stdout: String,
        stderr: String,
        findText: String
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
                applyPromptStyling(to: segmentAttr)
                applyStatusStyling(to: segmentAttr)
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

    private static func applyPromptStyling(to attr: NSMutableAttributedString) {
        let source = attr.string
        guard let regex = try? NSRegularExpression(pattern: #"\n\n([^\n]+) \$ ([^\n]+)\n"#) else {
            return
        }

        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in regex.matches(in: source, range: fullRange) {
            guard match.numberOfRanges == 3 else { continue }
            colorMatchGroup(match.range(at: 1), color: OutputPanelStyle.promptPathNSColor, in: attr)
            colorMatchGroup(match.range(at: 2), color: OutputPanelStyle.promptCommandNSColor, in: attr)
        }
    }

    private static func applyStatusStyling(to attr: NSMutableAttributedString) {
        let source = attr.string
        guard let regex = try? NSRegularExpression(pattern: #"\n([✓✗⊘])\n"#) else {
            return
        }

        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in regex.matches(in: source, range: fullRange) {
            guard match.numberOfRanges == 2 else { continue }
            let lineRange = match.range(at: 1)
            guard let range = Range(lineRange, in: source) else { continue }
            let marker = String(source[range])
            let color: NSColor
            switch marker {
            case "✓": color = NSColor(red: 0.45, green: 0.82, blue: 0.52, alpha: 1)
            case "✗": color = NSColor(red: 1.0, green: 0.55, blue: 0.55, alpha: 1)
            case "⊘": color = NSColor(white: 0.62, alpha: 1)
            default: continue
            }
            colorMatchGroup(lineRange, color: color, in: attr)
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

    private static func applyFindHighlight(to attr: NSMutableAttributedString, findText: String) {
        let source = attr.string as NSString
        var searchRange = NSRange(location: 0, length: source.length)
        let highlight = NSColor.systemYellow.withAlphaComponent(0.35)
        while searchRange.length > 0 {
            let found = source.range(
                of: findText,
                options: [.caseInsensitive],
                range: searchRange
            )
            guard found.location != NSNotFound else { break }
            attr.addAttribute(.backgroundColor, value: highlight, range: found)
            let nextLocation = found.location + found.length
            searchRange = NSRange(location: nextLocation, length: source.length - nextLocation)
        }
    }
}
