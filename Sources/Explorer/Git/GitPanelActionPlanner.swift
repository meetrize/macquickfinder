import Foundation

struct GitPanelPrimaryAction: Equatable {
    let title: String
    let kind: GitPanelOperationKind
    let isEnabled: Bool
    let disabledReason: String?
}

enum GitPanelActionPlanner {
    static func primaryAction(
        snapshot: GitWorkspaceSnapshot?,
        isOperating: Bool
    ) -> GitPanelPrimaryAction? {
        guard let snapshot else { return nil }
        guard !isOperating else {
            return GitPanelPrimaryAction(
                title: L10n.Git.Action.working,
                kind: .sync,
                isEnabled: false,
                disabledReason: nil
            )
        }

        switch snapshot.workspacePhase {
        case .cleanSynced:
            return GitPanelPrimaryAction(
                title: L10n.Git.Action.sync,
                kind: .sync,
                isEnabled: snapshot.hasUpstream,
                disabledReason: snapshot.hasUpstream ? nil : L10n.Git.Error.noUpstream
            )
        case .dirty:
            return GitPanelPrimaryAction(
                title: L10n.Git.Action.commitAndSync,
                kind: .commitAndSync,
                isEnabled: true,
                disabledReason: nil
            )
        case .aheadOnly:
            return GitPanelPrimaryAction(
                title: L10n.Git.Action.push,
                kind: .push,
                isEnabled: snapshot.hasUpstream,
                disabledReason: snapshot.hasUpstream ? nil : L10n.Git.Error.noUpstream
            )
        case .behindOrConflict:
            let hasConflict = !snapshot.conflictedPaths.isEmpty
            return GitPanelPrimaryAction(
                title: hasConflict ? L10n.Git.Action.resolveConflict : L10n.Git.Action.pull,
                kind: .pull,
                isEnabled: !hasConflict && snapshot.changeCount == 0,
                disabledReason: pullDisabledReason(snapshot: snapshot)
            )
        }
    }

    static func canPull(snapshot: GitWorkspaceSnapshot) -> Bool {
        snapshot.conflictedPaths.isEmpty
            && snapshot.changeCount == 0
            && snapshot.hasUpstream
    }

    static func pullDisabledReason(snapshot: GitWorkspaceSnapshot) -> String? {
        if !snapshot.conflictedPaths.isEmpty {
            return L10n.Git.Error.conflict
        }
        if snapshot.changeCount > 0 {
            return L10n.Git.Error.pullWithDirty
        }
        if !snapshot.hasUpstream {
            return L10n.Git.Error.noUpstream
        }
        return nil
    }

    static func canCommitOnly(snapshot: GitWorkspaceSnapshot, isOperating: Bool) -> Bool {
        !isOperating && snapshot.changeCount > 0
    }

    static func shouldConfirmLargeCommit(
        changeCount: Int,
        threshold: Int = GitPanelMetrics.largeCommitConfirmationThreshold
    ) -> Bool {
        changeCount > threshold
    }
}
