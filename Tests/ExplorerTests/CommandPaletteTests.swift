import XCTest
@testable import Explorer

final class CommandPaletteTests: XCTestCase {
    func testFuzzyMatcherPrefersPrefixMatch() {
        let items = [
            CommandPaletteResolvedItem(
                id: "toggle_snippets",
                title: "Show Snippets Panel",
                shortcutDisplay: nil,
                isEnabled: true,
                sectionTitle: nil
            ),
            CommandPaletteResolvedItem(
                id: "toggle_git",
                title: "Git Panel",
                shortcutDisplay: nil,
                isEnabled: true,
                sectionTitle: nil
            ),
        ]

        let filtered = CommandPaletteFuzzyMatcher.filter(
            items,
            query: "show",
            keywordsByID: [
                "toggle_snippets": ["snippets"],
                "toggle_git": ["git"],
            ]
        )

        XCTAssertEqual(filtered.first?.id, "toggle_snippets")
    }

    func testFuzzyMatcherMatchesKeywords() {
        let items = [
            CommandPaletteResolvedItem(
                id: "delete",
                title: "Delete",
                shortcutDisplay: nil,
                isEnabled: true,
                sectionTitle: nil
            )
        ]

        let filtered = CommandPaletteFuzzyMatcher.filter(
            items,
            query: "删除",
            keywordsByID: ["delete": ["删除", "delete"]]
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, "delete")
    }

    func testRegistrySkipsDisabledSelection() {
        let items = [
            CommandPaletteResolvedItem(
                id: "back",
                title: "Back",
                shortcutDisplay: nil,
                isEnabled: false,
                sectionTitle: nil
            ),
            CommandPaletteResolvedItem(
                id: "forward",
                title: "Forward",
                shortcutDisplay: nil,
                isEnabled: true,
                sectionTitle: nil
            ),
        ]

        XCTAssertEqual(CommandPaletteRegistry.moveSelection(from: 0, direction: 1, in: items), 1)
        XCTAssertEqual(CommandPaletteRegistry.selectableIndices(in: items), [1])
    }

    func testRecentsStoreKeepsMostRecentFirst() {
        let defaults = UserDefaults.standard
        let key = AppPreferences.CommandPalette.recents
        let original = defaults.data(forKey: key)
        defer {
            if let original {
                defaults.set(original, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        CommandPaletteRecentsStore.record("focus_search")
        CommandPaletteRecentsStore.record("toggle_snippets")
        CommandPaletteRecentsStore.record("focus_search")

        XCTAssertEqual(CommandPaletteRecentsStore.cachedLoad().prefix(2).map(\.rawValue), ["focus_search", "toggle_snippets"])
    }

    func testSnippetCommandIdentification() {
        let snippet = Snippet(
            name: "Demo",
            scriptType: .shell,
            scope: .anytime,
            content: "echo hi"
        )
        let id = CommandPaletteSnippetResolver.commandID(for: snippet)
        XCTAssertTrue(CommandPaletteSnippetResolver.isSnippetCommand(id))
        XCTAssertEqual(id.rawValue, "snippet:\(snippet.id.uuidString)")
    }
}
