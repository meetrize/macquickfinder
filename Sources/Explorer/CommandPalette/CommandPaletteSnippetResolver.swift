import FileList
import Foundation

@MainActor
enum CommandPaletteSnippetResolver {
    private static let idPrefix = "snippet:"

    struct Bundle {
        var items: [CommandPaletteResolvedItem]
        var keywordsByID: [CommandPaletteID: [String]]
    }

    static func isSnippetCommand(_ id: CommandPaletteID) -> Bool {
        id.rawValue.hasPrefix(idPrefix)
    }

    static func resolve(in context: CommandPaletteContext) -> Bundle {
        let snippets = SnippetStore.shared.visibleSnippets(
            cwd: context.currentPath,
            selectedItems: context.selectedItems,
            showHiddenFiles: context.showHiddenFiles
        )
        let sectionTitle = L10n.CommandPalette.snippetsSection
        var keywordsByID: [CommandPaletteID: [String]] = [:]
        let items = snippets.map { snippet in
            let id = commandID(for: snippet)
            keywordsByID[id] = snippetKeywords(for: snippet)
            return CommandPaletteResolvedItem(
                id: id,
                title: displayTitle(for: snippet),
                shortcutDisplay: nil,
                isEnabled: true,
                sectionTitle: sectionTitle
            )
        }
        return Bundle(items: items, keywordsByID: keywordsByID)
    }

    static func perform(id: CommandPaletteID, in context: CommandPaletteContext) {
        guard isSnippetCommand(id),
              let snippetID = snippetUUID(from: id),
              let snippet = SnippetStore.shared.snippet(id: snippetID) else {
            return
        }

        let executionContext = SnippetExecutionContext(
            cwd: context.currentPath,
            selectedItems: context.selectedItems.filter { !$0.isParentDirectoryEntry }
        )
        SnippetExecutor.shared.executeFromMenu(
            snippet,
            context: executionContext,
            layout: context.layout
        )
    }

    static func commandID(for snippet: Snippet) -> CommandPaletteID {
        CommandPaletteID(rawValue: "\(idPrefix)\(snippet.id.uuidString)")
    }

    private static func snippetUUID(from id: CommandPaletteID) -> UUID? {
        guard id.rawValue.hasPrefix(idPrefix) else { return nil }
        let raw = String(id.rawValue.dropFirst(idPrefix.count))
        return UUID(uuidString: raw)
    }

    private static func displayTitle(for snippet: Snippet) -> String {
        guard let badge = snippet.scope.shortBadge, !badge.isEmpty else {
            return snippet.name
        }
        return "\(snippet.name) · \(badge)"
    }

    private static func snippetKeywords(for snippet: Snippet) -> [String] {
        var keywords = [snippet.name, "snippet", "snippets", "脚本", "片段"]
        if let badge = snippet.scope.shortBadge {
            keywords.append(badge)
        }
        keywords.append(snippet.scope.kind.displayName)
        return keywords
    }
}
