import Foundation

@MainActor
enum GitService {
    static let largeCommitThreshold = GitPanelMetrics.largeCommitConfirmationThreshold
    static let pullUsesRebase = true

    private static let messageGenerator: GitCommitMessageGenerating = RuleBasedGitCommitMessageGenerator()

    static func initRepository(
        cwd: String,
        layout: ExplorerWindowLayoutState?,
        statusStore: GitStatusStore
    ) async -> String? {
        do {
            try await GitJobRunner.run(
                title: L10n.Git.Job.initRepository,
                arguments: ["init"],
                workingDirectory: cwd,
                layout: layout
            )
            await statusStore.refresh(cwd: cwd)
            return nil
        } catch let error as GitServiceError {
            return error.localizedDescription
        } catch {
            return error.localizedDescription
        }
    }

    static func pull(
        snapshot: GitWorkspaceSnapshot,
        cwd: String,
        layout: ExplorerWindowLayoutState?,
        statusStore: GitStatusStore
    ) async -> String? {
        if let reason = GitPanelActionPlanner.pullDisabledReason(snapshot: snapshot) {
            return reason
        }

        do {
            let arguments = pullUsesRebase ? ["pull", "--rebase"] : ["pull"]
            try await GitJobRunner.run(
                title: L10n.Git.Job.pull,
                arguments: arguments,
                workingDirectory: snapshot.repoRoot,
                layout: layout
            )
            await statusStore.refresh(cwd: cwd)
            return nil
        } catch let error as GitServiceError {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        } catch {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        }
    }

    static func commit(
        snapshot: GitWorkspaceSnapshot,
        cwd: String,
        commitMessage: String,
        scope: GitCommitScope,
        layout: ExplorerWindowLayoutState?,
        statusStore: GitStatusStore
    ) async -> String? {
        guard snapshot.changeCount > 0 else { return nil }

        do {
            try await stageChanges(snapshot: snapshot, scope: scope, layout: layout)
            let message = resolvedCommitMessage(
                commitMessage: commitMessage,
                snapshot: snapshot,
                scope: scope
            )
            guard !message.isEmpty else {
                throw GitServiceError.emptyCommitMessage
            }

            try await GitJobRunner.run(
                title: L10n.Git.Job.commit,
                arguments: ["commit", "-m", message],
                workingDirectory: snapshot.repoRoot,
                layout: layout
            )
            await statusStore.refresh(cwd: cwd)
            return nil
        } catch let error as GitServiceError {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        } catch {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        }
    }

    static func push(
        snapshot: GitWorkspaceSnapshot,
        cwd: String,
        layout: ExplorerWindowLayoutState?,
        statusStore: GitStatusStore
    ) async -> String? {
        guard snapshot.hasUpstream else {
            return L10n.Git.Error.noUpstream
        }

        do {
            try await GitJobRunner.run(
                title: L10n.Git.Job.push,
                arguments: ["push"],
                workingDirectory: snapshot.repoRoot,
                layout: layout
            )
            await statusStore.refresh(cwd: cwd)
            return nil
        } catch let error as GitServiceError {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        } catch {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        }
    }

    static func sync(
        snapshot: GitWorkspaceSnapshot,
        cwd: String,
        layout: ExplorerWindowLayoutState?,
        statusStore: GitStatusStore
    ) async -> String? {
        do {
            if snapshot.hasUpstream {
                let arguments = pullUsesRebase ? ["pull", "--rebase"] : ["pull"]
                try await GitJobRunner.run(
                    title: L10n.Git.Job.sync,
                    arguments: arguments,
                    workingDirectory: snapshot.repoRoot,
                    layout: layout
                )
            }
            await statusStore.refresh(cwd: cwd)
            if let refreshed = statusStore.snapshot, refreshed.aheadCount > 0, refreshed.hasUpstream {
                try await GitJobRunner.run(
                    title: L10n.Git.Job.push,
                    arguments: ["push"],
                    workingDirectory: snapshot.repoRoot,
                    layout: layout
                )
            }
            await statusStore.refresh(cwd: cwd)
            return nil
        } catch let error as GitServiceError {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        } catch {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        }
    }

    static func commitAndSync(
        snapshot: GitWorkspaceSnapshot,
        cwd: String,
        commitMessage: String,
        scope: GitCommitScope,
        layout: ExplorerWindowLayoutState?,
        statusStore: GitStatusStore
    ) async -> String? {
        let hadChanges = snapshot.changeCount > 0

        do {
            if hadChanges {
                try await stageChanges(snapshot: snapshot, scope: scope, layout: layout)
                let message = resolvedCommitMessage(
                    commitMessage: commitMessage,
                    snapshot: snapshot,
                    scope: scope
                )
                guard !message.isEmpty else {
                    throw GitServiceError.emptyCommitMessage
                }

                try await GitJobRunner.run(
                    title: L10n.Git.Job.commit,
                    arguments: ["commit", "-m", message],
                    workingDirectory: snapshot.repoRoot,
                    layout: layout
                )
            }

            if snapshot.hasUpstream {
                let arguments = pullUsesRebase ? ["pull", "--rebase"] : ["pull"]
                try await GitJobRunner.run(
                    title: L10n.Git.Job.pull,
                    arguments: arguments,
                    workingDirectory: snapshot.repoRoot,
                    layout: layout
                )
            }

            if hadChanges || snapshot.aheadCount > 0 {
                if snapshot.hasUpstream {
                    try await GitJobRunner.run(
                        title: L10n.Git.Job.push,
                        arguments: ["push"],
                        workingDirectory: snapshot.repoRoot,
                        layout: layout
                    )
                } else if hadChanges {
                    return L10n.Git.Error.noUpstream
                }
            }

            await statusStore.refresh(cwd: cwd)
            return nil
        } catch let error as GitServiceError {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        } catch {
            await statusStore.refresh(cwd: cwd)
            return error.localizedDescription
        }
    }

    private static func stageChanges(
        snapshot: GitWorkspaceSnapshot,
        scope: GitCommitScope,
        layout: ExplorerWindowLayoutState?
    ) async throws {
        switch scope {
        case .allChanges:
            try await GitJobRunner.run(
                title: L10n.Git.Job.stage,
                arguments: ["add", "-A"],
                workingDirectory: snapshot.repoRoot,
                layout: layout
            )
        case .selectedPaths(let paths):
            guard !paths.isEmpty else { return }
            try await GitJobRunner.run(
                title: L10n.Git.Job.stage,
                arguments: ["add", "--"] + paths,
                workingDirectory: snapshot.repoRoot,
                layout: layout
            )
        }
    }

    private static func resolvedCommitMessage(
        commitMessage: String,
        snapshot: GitWorkspaceSnapshot,
        scope: GitCommitScope
    ) -> String {
        let trimmed = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return messageGenerator.generate(
            repoRoot: snapshot.repoRoot,
            scope: scope,
            entries: snapshot.entries
        )
    }
}

extension GitServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return L10n.Git.Error.cancelled
        case .commandFailed(let message):
            return message
        case .emptyCommitMessage:
            return L10n.Git.Error.emptyCommitMessage
        }
    }
}
