import Foundation

enum ContentSearchGlobMatcher {
    /// 预编译的 glob 集合。一次搜索内复用，避免对每个文件重复编译正则。
    struct Compiled {
        private struct Pattern {
            let regex: NSRegularExpression
            let matchesPath: Bool

            func matches(path: String, fileName: String) -> Bool {
                let target = matchesPath ? path : fileName
                let range = NSRange(target.startIndex..<target.endIndex, in: target)
                return regex.firstMatch(in: target, options: [], range: range) != nil
            }
        }

        private let includePatterns: [Pattern]
        private let excludePatterns: [Pattern]

        init(includePatterns: [String], excludePatterns: [String]) {
            self.includePatterns = Self.compile(includePatterns)
            self.excludePatterns = Self.compile(excludePatterns)
        }

        func matches(relativePath: String, fileName: String) -> Bool {
            let normalizedPath = ContentSearchGlobMatcher.normalize(relativePath)
            let normalizedName = ContentSearchGlobMatcher.normalize(fileName)

            if excludePatterns.contains(where: { $0.matches(path: normalizedPath, fileName: normalizedName) }) {
                return false
            }

            guard !includePatterns.isEmpty else { return true }
            return includePatterns.contains { $0.matches(path: normalizedPath, fileName: normalizedName) }
        }

        /// 目录剪枝：只有「整个目录路径本身」命中排除规则时才跳过其子树，
        /// 避免 `node_modules/**`、`.git/**` 这类大目录被完整遍历后再逐文件过滤。
        func excludesDirectory(relativePath: String) -> Bool {
            guard !excludePatterns.isEmpty else { return false }
            let directoryPath = ContentSearchGlobMatcher.normalize(relativePath) + "/"
            let directoryName = (relativePath as NSString).lastPathComponent
            return excludePatterns.contains { $0.matches(path: directoryPath, fileName: directoryName) }
        }

        private static func compile(_ patterns: [String]) -> [Pattern] {
            patterns.compactMap { pattern in
                let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      let regex = try? NSRegularExpression(
                          pattern: globToRegex(trimmed),
                          options: [.caseInsensitive]
                      ) else {
                    return nil
                }
                return Pattern(regex: regex, matchesPath: trimmed.contains("/"))
            }
        }
    }

    /// Returns whether `relativePath` (POSIX, relative to search root) passes include/exclude globs.
    static func matches(
        relativePath: String,
        fileName: String,
        includePatterns: [String],
        excludePatterns: [String]
    ) -> Bool {
        Compiled(includePatterns: includePatterns, excludePatterns: excludePatterns)
            .matches(relativePath: relativePath, fileName: fileName)
    }

    static func normalize(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/")
    }

    static func patternMatches(pattern: String, path: String, fileName: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let target: String
        if trimmed.contains("/") {
            target = path
        } else {
            target = fileName
        }

        guard let regex = try? NSRegularExpression(pattern: globToRegex(trimmed), options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(target.startIndex..<target.endIndex, in: target)
        return regex.firstMatch(in: target, options: [], range: range) != nil
    }

    static func globToRegex(_ glob: String) -> String {
        var regex = "^"
        var index = glob.startIndex

        while index < glob.endIndex {
            let char = glob[index]
            if char == "*" {
                let next = glob.index(after: index)
                if next < glob.endIndex, glob[next] == "*" {
                    regex += ".*"
                    index = glob.index(after: next)
                } else {
                    regex += "[^/]*"
                    index = next
                }
            } else if char == "?" {
                regex += "[^/]"
                index = glob.index(after: index)
            } else if ".+^${}()|[]\\".contains(char) {
                regex += NSRegularExpression.escapedPattern(for: String(char))
                index = glob.index(after: index)
            } else {
                regex += NSRegularExpression.escapedPattern(for: String(char))
                index = glob.index(after: index)
            }
        }

        regex += "$"
        return regex
    }
}
