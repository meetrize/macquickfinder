import AppKit
import Foundation

extension PreviewTextSearchHighlighter {
    static func canRevealLine(_ lineNumber: Int, in text: String) -> Bool {
        guard lineNumber >= 1, !text.isEmpty else { return false }

        let nsText = text as NSString
        var currentLine = 1
        var location = 0

        while location <= nsText.length {
            if currentLine == lineNumber {
                return true
            }

            guard location < nsText.length else { break }
            let found = nsText.rangeOfCharacter(
                from: CharacterSet.newlines,
                range: NSRange(location: location, length: nsText.length - location)
            )
            if found.location == NSNotFound { break }
            currentLine += 1
            location = found.location + found.length
        }

        return false
    }

    static func scrollToLine(_ lineNumber: Int, in textView: NSTextView) {
        guard lineNumber >= 1 else { return }
        let text = textView.string as NSString
        guard text.length > 0 else { return }

        var currentLine = 1
        var location = 0

        while location <= text.length {
            if currentLine == lineNumber {
                let range = NSRange(location: min(location, text.length), length: 0)
                textView.setSelectedRange(range)
                textView.scrollRangeToVisible(range)
                return
            }

            guard location < text.length else { break }
            let found = text.rangeOfCharacter(
                from: CharacterSet.newlines,
                range: NSRange(location: location, length: text.length - location)
            )
            if found.location == NSNotFound { break }
            currentLine += 1
            location = found.location + found.length
        }
    }

    static func firstMatchIndexOnLine(
        lineNumber: Int,
        in text: String,
        matchRanges: [NSRange]
    ) -> Int? {
        guard lineNumber >= 1 else { return nil }
        let nsText = text as NSString
        var currentLine = 1
        var lineStart = 0

        while currentLine <= lineNumber {
            if currentLine == lineNumber {
                let lineEnd: Int
                if lineStart >= nsText.length {
                    lineEnd = lineStart
                } else {
                    let found = nsText.rangeOfCharacter(
                        from: .newlines,
                        range: NSRange(location: lineStart, length: nsText.length - lineStart)
                    )
                    lineEnd = found.location == NSNotFound ? nsText.length : found.location
                }
                let lineRange = NSRange(location: lineStart, length: max(0, lineEnd - lineStart))
                for (index, matchRange) in matchRanges.enumerated() {
                    if NSIntersectionRange(matchRange, lineRange).length > 0 {
                        return index
                    }
                }
                return matchRanges.isEmpty ? nil : 0
            }

            guard lineStart < nsText.length else { break }
            let found = nsText.rangeOfCharacter(
                from: .newlines,
                range: NSRange(location: lineStart, length: nsText.length - lineStart)
            )
            if found.location == NSNotFound { break }
            currentLine += 1
            lineStart = found.location + found.length
        }

        return nil
    }
}
