import Foundation

struct CommandPaletteID: Hashable, Codable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }
}

struct CommandPaletteResolvedItem: Identifiable, Equatable {
    let id: CommandPaletteID
    let title: String
    let shortcutDisplay: String?
    let isEnabled: Bool
    let sectionTitle: String?
}

@MainActor
struct CommandPaletteDefinition {
    let id: CommandPaletteID
    let title: (CommandPaletteContext) -> String
    let category: String
    let keywords: [String]
    let shortcutDisplay: String?
    let priority: Int
    let isEnabled: (CommandPaletteContext) -> Bool
    let perform: (CommandPaletteContext) -> Void

    func resolve(in context: CommandPaletteContext) -> CommandPaletteResolvedItem {
        CommandPaletteResolvedItem(
            id: id,
            title: title(context),
            shortcutDisplay: shortcutDisplay,
            isEnabled: isEnabled(context),
            sectionTitle: category
        )
    }
}
