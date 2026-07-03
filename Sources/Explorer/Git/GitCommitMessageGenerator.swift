import Foundation

protocol GitCommitMessageGenerating: Sendable {
    func generate(
        repoRoot: String,
        scope: GitCommitScope,
        entries: [GitPorcelainEntry]
    ) -> String
}

struct RuleBasedGitCommitMessageGenerator: GitCommitMessageGenerating {
    func generate(
        repoRoot: String,
        scope: GitCommitScope,
        entries: [GitPorcelainEntry]
    ) -> String {
        let paths: [String]
        switch scope {
        case .allChanges:
            paths = entries.map(\.path)
        case .selectedPaths(let selected):
            paths = selected
        }

        guard !paths.isEmpty else { return "" }

        if let directorySummary = directoryClusterSummary(paths: paths) {
            return directorySummary
        }

        return L10n.Git.Commit.generatedFiles(paths.count)
    }

    private func directoryClusterSummary(paths: [String]) -> String? {
        let directories = paths.map { ($0 as NSString).deletingLastPathComponent }
        let normalized = directories.map { $0.isEmpty ? "." : $0 }
        guard !normalized.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        for directory in normalized {
            counts[directory, default: 0] += 1
        }

        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        let ratio = Double(top.value) / Double(paths.count)
        guard ratio >= 0.6, top.key != "." else { return nil }

        return L10n.Git.Commit.generatedDirectory(top.key, top.value)
    }
}
