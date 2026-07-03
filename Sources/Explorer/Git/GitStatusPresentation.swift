import Foundation
import SwiftUI

enum GitStatusPresentation {
    static let visibleChangeLimit = 8

    static func statusStrip(snapshot: GitWorkspaceSnapshot) -> String {
        var parts: [String] = []
        if let branch = snapshot.currentBranch, !branch.isEmpty {
            parts.append(branch)
        } else {
            parts.append("—")
        }

        if snapshot.hasUpstream {
            if snapshot.aheadCount > 0 {
                parts.append(L10n.Git.Status.ahead(snapshot.aheadCount))
            }
            if snapshot.behindCount > 0 {
                parts.append(L10n.Git.Status.behind(snapshot.behindCount))
            }
        }

        if snapshot.changeCount > 0 {
            parts.append(L10n.Git.Status.changes(snapshot.changeCount))
        }

        return parts.joined(separator: " · ")
    }

    static func chipLabel(snapshot: GitWorkspaceSnapshot) -> String {
        var parts: [String] = []
        if let branch = snapshot.currentBranch, !branch.isEmpty {
            parts.append(branch)
        }
        if snapshot.changeCount > 0 {
            parts.append("\(snapshot.changeCount)●")
        } else if snapshot.aheadCount > 0 {
            parts.append(L10n.Git.Chip.ahead(snapshot.aheadCount))
        } else if snapshot.behindCount > 0 {
            parts.append(L10n.Git.Chip.behind(snapshot.behindCount))
        }
        return parts.joined(separator: " · ")
    }

    static func cardTitle(for phase: GitWorkspacePhase, snapshot: GitWorkspaceSnapshot) -> String {
        switch phase {
        case .cleanSynced:
            return L10n.Git.Status.clean
        case .dirty:
            return L10n.Git.Status.dirty(snapshot.changeCount)
        case .aheadOnly:
            return L10n.Git.Status.ahead(snapshot.aheadCount)
        case .behindOrConflict:
            if !snapshot.conflictedPaths.isEmpty {
                return L10n.Git.Status.conflict
            }
            return L10n.Git.Status.behind(snapshot.behindCount)
        }
    }

    static func cardColor(for phase: GitWorkspacePhase) -> Color {
        switch phase {
        case .cleanSynced:
            return .green
        case .dirty:
            return .orange
        case .aheadOnly:
            return .blue
        case .behindOrConflict:
            return .red
        }
    }

    static func statusBadge(for status: GitPathStatus) -> String {
        switch status {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .untracked: return "?"
        case .conflict: return "!"
        }
    }

    static func statusBadgeColor(for status: GitPathStatus) -> Color {
        switch status {
        case .modified: return .orange
        case .added, .untracked: return .green
        case .deleted, .conflict: return .red
        case .renamed: return .blue
        }
    }

    static func displayName(for entry: GitPorcelainEntry) -> String {
        (entry.path as NSString).lastPathComponent
    }

    static func absolutePath(for entry: GitPorcelainEntry, repoRoot: String) -> String {
        (repoRoot as NSString).appendingPathComponent(entry.path)
    }

    static func visibleEntries(
        from entries: [GitPorcelainEntry],
        showsAll: Bool
    ) -> (visible: [GitPorcelainEntry], remainingCount: Int) {
        guard !showsAll, entries.count > visibleChangeLimit else {
            return (entries, 0)
        }
        let visible = Array(entries.prefix(visibleChangeLimit))
        return (visible, entries.count - visible.count)
    }
}
