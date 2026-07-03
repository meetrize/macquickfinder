import Foundation

enum GitWorkspaceFSEventsPolicy {
    static func shouldRefresh(eventPaths: [String], repoRoot: String) -> Bool {
        let normalizedRoot = GitRepositoryDetector.normalizedRepoRoot(repoRoot)
        return eventPaths.contains { path in
            shouldRefresh(eventPath: path, repoRoot: normalizedRoot)
        }
    }

    static func shouldRefresh(eventPath: String, repoRoot: String) -> Bool {
        let normalizedRoot = GitRepositoryDetector.normalizedRepoRoot(repoRoot)
        let normalizedPath = URL(fileURLWithPath: eventPath).resolvingSymlinksInPath().path

        guard normalizedPath == normalizedRoot || normalizedPath.hasPrefix(normalizedRoot + "/") else {
            return false
        }

        let relativePath = relativePath(from: normalizedPath, repoRoot: normalizedRoot)
        guard !relativePath.isEmpty else { return true }

        if relativePath == ".git" || relativePath.hasPrefix(".git/") {
            return shouldRefreshGitDirectory(relativePath: relativePath)
        }

        return true
    }

    private static func relativePath(from path: String, repoRoot: String) -> String {
        guard path != repoRoot else { return "" }
        return String(path.dropFirst(repoRoot.count + 1))
    }

    private static func shouldRefreshGitDirectory(relativePath: String) -> Bool {
        if relativePath.hasPrefix(".git/objects/") { return false }
        if relativePath.hasPrefix(".git/logs/") { return false }
        if relativePath.hasSuffix(".lock") { return false }
        return true
    }
}
