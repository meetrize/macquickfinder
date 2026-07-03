import Foundation

enum GitPanelOperationKind: String, Equatable, Sendable {
    case sync
    case pull
    case commit
    case push
    case commitAndSync
    case initRepository
}
