import Foundation

enum GitPathStatus: String, Equatable, Sendable, CaseIterable {
    case modified
    case added
    case deleted
    case renamed
    case untracked
    case conflict
}

enum GitWorkspacePhase: Equatable, Sendable {
    case cleanSynced
    case dirty
    case aheadOnly
    case behindOrConflict
}

struct GitPorcelainEntry: Equatable, Identifiable, Sendable {
    var id: String { path }
    let status: GitPathStatus
    /// Display path (new path for renames).
    let path: String
    let oldPath: String?

    init(status: GitPathStatus, path: String, oldPath: String? = nil) {
        self.status = status
        self.path = path
        self.oldPath = oldPath
    }
}

struct GitWorkspaceSnapshot: Equatable, Sendable {
    let repoRoot: String
    let currentBranch: String?
    let entries: [GitPorcelainEntry]
    let aheadCount: Int
    let behindCount: Int
    let hasUpstream: Bool
    let lastRefreshedAt: Date

    var changeCount: Int { entries.count }

    var conflictedPaths: [String] {
        entries.filter { $0.status == .conflict }.map(\.path)
    }

    var workspacePhase: GitWorkspacePhase {
        GitWorkspacePhaseResolver.resolve(snapshot: self)
    }
}

enum GitWorkspacePhaseResolver {
    static func resolve(snapshot: GitWorkspaceSnapshot) -> GitWorkspacePhase {
        if !snapshot.conflictedPaths.isEmpty {
            return .behindOrConflict
        }
        if !snapshot.entries.isEmpty {
            return .dirty
        }
        if snapshot.behindCount > 0 {
            return .behindOrConflict
        }
        if snapshot.aheadCount > 0 {
            return .aheadOnly
        }
        return .cleanSynced
    }
}
