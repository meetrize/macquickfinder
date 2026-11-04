import AppKit

enum PreviewTextSearchHighlighter {
    static func findMatchRanges(of query: String, in text: String) -> [NSRange] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !text.isEmpty else { return [] }

        // 一次正则扫描比「每命中一次就 range(of:) 一次」快得多；
        // 常见关键字在 60k 字符预览里可能有数千个命中。
        guard let regex = try? NSRegularExpression(
            pattern: NSRegularExpression.escapedPattern(for: trimmed),
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let nsText = text as NSString
        var ranges: [NSRange] = []
        regex.enumerateMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        ) { result, _, _ in
            guard let result else { return }
            let range = result.range
            guard range.location != NSNotFound, range.length > 0 else { return }
            ranges.append(range)
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

    /// 单次最多着色的匹配数。全文搜索的短关键字可能在大文件里有数万个命中，
    /// 逐个 addAttribute 会阻塞主线程；保留计数与跳转能力，只对当前附近的命中着色。
    static let maxAppliedHighlights = 2_000

    static func applyHighlights(
        in storage: NSTextStorage,
        query: String,
        matchRanges precomputedRanges: [NSRange]? = nil,
        currentIndex: Int,
        textView: NSTextView,
        scrollToCurrent: Bool
    ) -> (ranges: [NSRange], applied: [NSRange]) {
        // 调用方已经做过一次扫描时直接复用，避免重复 findMatchRanges。
        let matchRanges = precomputedRanges ?? findMatchRanges(of: query, in: storage.string)
        guard !matchRanges.isEmpty else { return ([], []) }

        let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let allMatchColor = isDark
            ? NSColor.systemYellow.withAlphaComponent(0.35)
            : NSColor.systemYellow.withAlphaComponent(0.45)
        let currentMatchColor = isDark
            ? NSColor.systemOrange.withAlphaComponent(0.55)
            : NSColor.systemOrange.withAlphaComponent(0.65)

        let clampedIndex = min(max(0, currentIndex), matchRanges.count - 1)
        let window: Range<Int>
        if matchRanges.count <= maxAppliedHighlights {
            window = 0..<matchRanges.count
        } else {
            let half = maxAppliedHighlights / 2
            let lower = min(
                max(0, clampedIndex - half),
                max(0, matchRanges.count - maxAppliedHighlights)
            )
            window = lower..<min(matchRanges.count, lower + maxAppliedHighlights)
        }

        storage.beginEditing()
        var applied: [NSRange] = []
        for index in window {
            let range = matchRanges[index]
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

    static func advanceMatchIndex(current: Int, matchCount: Int, backward: Bool) -> Int {
        guard matchCount > 0 else { return 0 }
        if backward {
            return (current - 1 + matchCount) % matchCount
        }
        return (current + 1) % matchCount
    }
}
