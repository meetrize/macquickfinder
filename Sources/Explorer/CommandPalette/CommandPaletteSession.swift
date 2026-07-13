import Foundation

@MainActor
struct CommandPaletteSession {
    let context: CommandPaletteContext
    let baseItems: [CommandPaletteResolvedItem]
    let recents: [CommandPaletteID]
    let snippetItems: [CommandPaletteResolvedItem]
    let snippetKeywordsByID: [CommandPaletteID: [String]]
    let staticKeywordsByID: [CommandPaletteID: [String]]

    init(context: CommandPaletteContext) {
        self.context = context
        self.baseItems = CommandPaletteRegistry.resolveBaseItems(in: context)
        self.recents = CommandPaletteRecentsStore.cachedLoad()
        let snippetBundle = CommandPaletteSnippetResolver.resolve(in: context)
        self.snippetItems = snippetBundle.items
        self.snippetKeywordsByID = snippetBundle.keywordsByID
        self.staticKeywordsByID = CommandPaletteRegistry.fuzzyKeywordsByID
    }

    var snippetsSectionTitle: String {
        L10n.CommandPalette.snippetsSection
    }

    func filteredItems(query: String) -> [CommandPaletteResolvedItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let staticItems: [CommandPaletteResolvedItem]
        if trimmed.isEmpty {
            staticItems = CommandPaletteRegistry.defaultList(from: baseItems, recents: recents)
        } else {
            staticItems = CommandPaletteFuzzyMatcher.filter(
                baseItems,
                query: trimmed,
                keywordsByID: staticKeywordsByID
            )
        }

        let matchedSnippets: [CommandPaletteResolvedItem]
        if trimmed.isEmpty {
            matchedSnippets = snippetItems
        } else {
            matchedSnippets = CommandPaletteFuzzyMatcher.filter(
                snippetItems,
                query: trimmed,
                keywordsByID: snippetKeywordsByID
            )
        }

        guard !matchedSnippets.isEmpty else { return staticItems }
        return staticItems + matchedSnippets
    }

    func staticItemCount(in displayedItems: [CommandPaletteResolvedItem], query: String) -> Int {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return CommandPaletteRegistry.defaultList(from: baseItems, recents: recents).count
        }
        return CommandPaletteFuzzyMatcher.filter(
            baseItems,
            query: trimmed,
            keywordsByID: staticKeywordsByID
        ).count
    }
}
