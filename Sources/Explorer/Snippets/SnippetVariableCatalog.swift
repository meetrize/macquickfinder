import Foundation

struct SnippetVariableDefinition: Identifiable, Hashable {
    var id: String { token }
    let token: String
    let description: String
}

enum SnippetVariableCatalog {
    static let all: [SnippetVariableDefinition] = [
        SnippetVariableDefinition(token: "%p", description: L10n.Snippets.Variable.p),
        SnippetVariableDefinition(token: "%d", description: L10n.Snippets.Variable.d),
        SnippetVariableDefinition(token: "%P", description: L10n.Snippets.Variable.capitalP),
        SnippetVariableDefinition(token: "%f", description: L10n.Snippets.Variable.f),
        SnippetVariableDefinition(token: "%F", description: L10n.Snippets.Variable.capitalF),
        SnippetVariableDefinition(token: "%n", description: L10n.Snippets.Variable.n),
        SnippetVariableDefinition(token: "%b", description: L10n.Snippets.Variable.b),
        SnippetVariableDefinition(token: "%e", description: L10n.Snippets.Variable.e),
        SnippetVariableDefinition(token: "%N", description: L10n.Snippets.Variable.capitalN),
        SnippetVariableDefinition(token: "%q", description: L10n.Snippets.Variable.q),
        SnippetVariableDefinition(token: "%Q", description: L10n.Snippets.Variable.capitalQ),
        SnippetVariableDefinition(token: "%h", description: L10n.Snippets.Variable.h),
        SnippetVariableDefinition(token: "%u", description: L10n.Snippets.Variable.u),
        SnippetVariableDefinition(token: "%w", description: L10n.Snippets.Variable.w),
        SnippetVariableDefinition(token: "%date", description: L10n.Snippets.Variable.date),
        SnippetVariableDefinition(token: "%uuid", description: L10n.Snippets.Variable.uuid),
    ]

    static let supportedTokens: [String] = all.map(\.token).sorted { $0.count > $1.count }
}
