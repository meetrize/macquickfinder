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

        var result = AttributedString()
        for segment in OutputSessionFormatting.transcriptSegments(from: stdout) {
            var segmentAttr = AttributedString(segment.text)
            segmentAttr.foregroundColor = segment.isStderr
                ? OutputPanelStyle.stderrColor
                : OutputPanelStyle.stdoutColor
            if !segment.isStderr {
                applyPromptStyling(to: &segmentAttr)
                applyStatusStyling(to: &segmentAttr)
            }
            result.append(segmentAttr)
        }

        if !stderr.isEmpty {
            if !result.characters.isEmpty {
                result.append(AttributedString("\n"))
            }
            var stderrAttr = AttributedString(stderr)
            stderrAttr.foregroundColor = OutputPanelStyle.stderrColor
            result.append(stderrAttr)
        }

        if !findText.isEmpty {
            applyFindHighlight(to: &result, findText: findText)
        }

        return result
    }

    private static func applyPromptStyling(to attr: inout AttributedString) {
        let source = String(attr.characters)
        guard let regex = try? NSRegularExpression(pattern: #"\n\n([^\n]+) \$ ([^\n]+)\n"#) else {
            return
        }

        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in regex.matches(in: source, range: fullRange) {
            guard match.numberOfRanges == 3 else { continue }
            colorMatchGroup(match.range(at: 1), in: source, color: OutputPanelStyle.promptPathColor, attr: &attr)
            colorMatchGroup(match.range(at: 2), in: source, color: OutputPanelStyle.promptCommandColor, attr: &attr)
        }
    }

    private static func applyStatusStyling(to attr: inout AttributedString) {
        let source = String(attr.characters)
        guard let regex = try? NSRegularExpression(pattern: #"\n([✓✗⊘])\n"#) else {
            return
        }

        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in regex.matches(in: source, range: fullRange) {
            guard match.numberOfRanges == 2 else { continue }
            let lineRange = match.range(at: 1)
            guard let range = Range(lineRange, in: source) else { continue }
            let marker = String(source[range])
            let color: Color
            switch marker {
            case "✓": color = OutputPanelStyle.completionSuccessColor
            case "✗": color = OutputPanelStyle.completionFailureColor
            case "⊘": color = OutputPanelStyle.completionCancelledColor
            default: continue
            }
            colorMatchGroup(lineRange, in: source, color: color, attr: &attr)
        }
    }

    private static func colorMatchGroup(
        _ nsRange: NSRange,
        in source: String,
        color: Color,
        attr: inout AttributedString
    ) {
        guard let range = Range(nsRange, in: source) else { return }
        guard let lower = AttributedString.Index(range.lowerBound, within: attr),
              let upper = AttributedString.Index(range.upperBound, within: attr) else {
            return
        }
        attr[lower..<upper].foregroundColor = color
    }

    private static func applyFindHighlight(to attr: inout AttributedString, findText: String) {
        var searchStart = attr.startIndex
        while searchStart < attr.endIndex,
              let range = attr[searchStart...].range(
                of: findText,
                options: .caseInsensitive,
                locale: nil
              ) {
            attr[range].backgroundColor = OutputPanelStyle.findHighlightColor
            searchStart = range.upperBound
        }
    }
}
