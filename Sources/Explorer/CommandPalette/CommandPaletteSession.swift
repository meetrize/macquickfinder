import Foundation

@MainActor
struct CommandPaletteSession {
    let context: CommandPaletteContext
    let baseItems: [CommandPaletteResolvedItem]
    let recents: [CommandPaletteID]

    init(context: CommandPaletteContext) {
        self.context = context
        self.baseItems = CommandPaletteRegistry.resolveBaseItems(in: context)
        self.recents = CommandPaletteRecentsStore.cachedLoad()
    }

    func filteredItems(query: String) -> [CommandPaletteResolvedItem] {
        CommandPaletteRegistry.filteredItems(
            baseItems: baseItems,
            recents: recents,
            query: query
        )
    }
}
