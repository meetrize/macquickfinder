import Foundation

enum GitWorkspaceReader {
    static func loadSnapshot(
        cwd: String,
        cli: GitCLI = .live,
        now: Date = Date()
    ) throws -> GitWorkspaceSnapshot? {
        guard let repoRoot = GitRepositoryDetector.findRepoRoot(from: cwd) else {
            return nil
        }

        let branch = currentBranch(repoRoot: repoRoot, cli: cli)
        let porcelain = try cli.runData(["status", "--porcelain=v1", "-z"], workingDirectory: repoRoot)
        let entries = GitPorcelainParser.parse(zTerminated: porcelain.stdout)
        let upstream = upstreamCounts(repoRoot: repoRoot, cli: cli)
        let recentCommits = recentCommitLog(repoRoot: repoRoot, cli: cli)

        return GitWorkspaceSnapshot(
            repoRoot: repoRoot,
            currentBranch: branch,
            entries: entries,
            aheadCount: upstream.ahead,
            behindCount: upstream.behind,
            hasUpstream: upstream.hasUpstream,
            recentCommits: recentCommits,
            lastRefreshedAt: now
        )
    }

    private static func recentCommitLog(repoRoot: String, cli: GitCLI) -> [GitCommitEntry] {
        guard let data = try? cli.runData(
            [
                "log",
                "-\(GitLogParser.defaultLimit)",
                "-z",
                "--format=\(gitLogFormat)",
            ],
            workingDirectory: repoRoot
        ).stdout else {
            return []
        }
        return GitLogParser.parse(zTerminated: data)
    }

    private static let logFieldSeparator = "\u{1f}"
    private static let gitLogFormat = "%H\(logFieldSeparator)%h\(logFieldSeparator)%s\(logFieldSeparator)%cr"

    private static func currentBranch(repoRoot: String, cli: GitCLI) -> String? {
        guard let branch = try? cli.run(["branch", "--show-current"], workingDirectory: repoRoot),
              !branch.isEmpty else {
            return nil
        }
        return branch
    }

    private static func upstreamCounts(
        repoRoot: String,
        cli: GitCLI
    ) -> (ahead: Int, behind: Int, hasUpstream: Bool) {
        guard hasUpstream(repoRoot: repoRoot, cli: cli) else {
            return (0, 0, false)
        }
        guard let output = try? cli.run(
            ["rev-list", "--left-right", "--count", "HEAD...@{u}"],
            workingDirectory: repoRoot
        ) else {
            return (0, 0, false)
        }

        let parts = output.split(whereSeparator: \.isWhitespace)
        guard parts.count == 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else {
            return (0, 0, true)
        }
        return (ahead, behind, true)
    }

    private static func hasUpstream(repoRoot: String, cli: GitCLI) -> Bool {
        let result = try? cli.run(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            workingDirectory: repoRoot
        )
        guard let result, !result.isEmpty else { return false }
        return true
    }
}
