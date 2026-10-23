import Foundation

enum ExplorerPaneID: String, CaseIterable, Identifiable, Sendable {
    case primary
    case secondary

    var id: String { rawValue }

    var other: ExplorerPaneID {
        switch self {
        case .primary: return .secondary
        case .secondary: return .primary
        }
    }
}
