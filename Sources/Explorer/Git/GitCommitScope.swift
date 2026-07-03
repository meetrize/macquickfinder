import Foundation

enum GitCommitScope: Equatable, Sendable {
    case allChanges
    case selectedPaths([String])
}
