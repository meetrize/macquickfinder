import Foundation

enum GitRepositoryDetector {
    /// Walks from `path` upward until a `.git` file or directory is found.
    static func findRepoRoot(from path: String) -> String? {
        let fileManager = FileManager.default
        var current = normalizedExistingPath(path, fileManager: fileManager)
        guard !current.isEmpty else { return nil }

        while true {
            if isGitRoot(current, fileManager: fileManager) {
                return current
            }
            if current == "/" {
                return nil
            }
            current = (current as NSString).deletingLastPathComponent
        }
    }

    private static func normalizedExistingPath(_ path: String, fileManager: FileManager) -> String {
        let candidate = (path as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: candidate, isDirectory: &isDirectory), isDirectory.boolValue {
            return candidate
        }
        return (candidate as NSString).deletingLastPathComponent
    }

    private static func isGitRoot(_ directory: String, fileManager: FileManager) -> Bool {
        let gitPath = (directory as NSString).appendingPathComponent(".git")
        return fileManager.fileExists(atPath: gitPath)
    }

    /// Compares repository roots after standardizing paths and resolving symlinks.
    static func rootsEqual(_ lhs: String, _ rhs: String) -> Bool {
        normalizedRepoRoot(lhs) == normalizedRepoRoot(rhs)
    }

    static func normalizedRepoRoot(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }
}
