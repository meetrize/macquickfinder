import Foundation

enum CommandPaletteFuzzyMatcher {
    struct ScoredItem: Equatable {
        let item: CommandPaletteResolvedItem
        let score: Int
    }

    static func filter(
        _ items: [CommandPaletteResolvedItem],
        query: String,
        keywordsByID: [CommandPaletteID: [String]]
    ) -> [CommandPaletteResolvedItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }

        let scored = items.compactMap { item -> ScoredItem? in
            let keywords = keywordsByID[item.id] ?? []
            guard let score = matchScore(query: trimmed, title: item.title, keywords: keywords) else {
                return nil
            }
            return ScoredItem(item: item, score: score)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title) == .orderedAscending
            }
            .map(\.item)
    }

    static func matchScore(query: String, title: String, keywords: [String]) -> Int? {
        let normalizedQuery = query.lowercased()
        let normalizedTitle = title.lowercased()

        if normalizedTitle.hasPrefix(normalizedQuery) {
            return 1_000 + (normalizedTitle.count - normalizedQuery.count)
        }

        if let subsequenceScore = subsequenceScore(query: normalizedQuery, in: normalizedTitle) {
            return 500 + subsequenceScore
        }

        for keyword in keywords {
            let normalizedKeyword = keyword.lowercased()
            if normalizedKeyword.hasPrefix(normalizedQuery) {
                return 300 + (normalizedKeyword.count - normalizedQuery.count)
            }
            if let subsequenceScore = subsequenceScore(query: normalizedQuery, in: normalizedKeyword) {
                return 200 + subsequenceScore
            }
        }

        return nil
    }

    static func subsequenceScore(query: String, in text: String) -> Int? {
        guard !query.isEmpty else { return 0 }

        var score = 0
        var queryIndex = query.startIndex
        var previousMatch: String.Index?

        for index in text.indices {
            guard query[queryIndex] == text[index] else { continue }

            if let previousMatch, text.index(after: previousMatch) == index {
                score += 12
            } else if text[index] == text[text.startIndex] || previousMatch == nil {
                score += 8
            } else {
                score += 4
            }

            previousMatch = index
            queryIndex = query.index(after: queryIndex)
            if queryIndex == query.endIndex {
                return score
            }
        }

        return queryIndex == query.endIndex ? score : nil
    }
}
