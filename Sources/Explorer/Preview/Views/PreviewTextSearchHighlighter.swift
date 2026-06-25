import AppKit

enum PreviewTextSearchHighlighter {
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

    static func clearHighlights(in storage: NSTextStorage, ranges: [NSRange]) {
        guard !ranges.isEmpty else { return }
        storage.beginEditing()
        for range in ranges {
            guard range.location != NSNotFound, NSMaxRange(range) <= storage.length else { continue }
            storage.removeAttribute(.backgroundColor, range: range)
        }
        storage.endEditing()
    }

    static func applyHighlights(
        in storage: NSTextStorage,
        query: String,
        currentIndex: Int,
        textView: NSTextView,
        scrollToCurrent: Bool
    ) -> (ranges: [NSRange], applied: [NSRange]) {
        let matchRanges = findMatchRanges(of: query, in: storage.string)
        guard !matchRanges.isEmpty else { return ([], []) }

        let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let allMatchColor = isDark
            ? NSColor.systemYellow.withAlphaComponent(0.35)
            : NSColor.systemYellow.withAlphaComponent(0.45)
        let currentMatchColor = isDark
            ? NSColor.systemOrange.withAlphaComponent(0.55)
            : NSColor.systemOrange.withAlphaComponent(0.65)

        let clampedIndex = min(max(0, currentIndex), matchRanges.count - 1)
        storage.beginEditing()
        var applied: [NSRange] = []
        for (index, range) in matchRanges.enumerated() {
            guard range.location != NSNotFound, NSMaxRange(range) <= storage.length else { continue }
            let color = index == clampedIndex ? currentMatchColor : allMatchColor
            storage.addAttribute(.backgroundColor, value: color, range: range)
            applied.append(range)
        }
        storage.endEditing()

        if scrollToCurrent, clampedIndex < matchRanges.count {
            scrollToRange(matchRanges[clampedIndex], in: textView)
        }

        return (matchRanges, applied)
    }

    static func scrollToRange(_ range: NSRange, in textView: NSTextView) {
        textView.scrollRangeToVisible(range)
    }
}
