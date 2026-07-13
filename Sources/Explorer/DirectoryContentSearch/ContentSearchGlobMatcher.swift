import Foundation

enum ContentSearchGlobMatcher {
    /// Returns whether `relativePath` (POSIX, relative to search root) passes include/exclude globs.
    static func matches(
        relativePath: String,
        fileName: String,
        includePatterns: [String],
        excludePatterns: [String]
    ) -> Bool {
        let normalizedPath = normalize(relativePath)
        let normalizedName = normalize(fileName)

        if excludePatterns.contains(where: { patternMatches(pattern: $0, path: normalizedPath, fileName: normalizedName) }) {
            return false
        }

        guard !includePatterns.isEmpty else { return true }
        return includePatterns.contains { patternMatches(pattern: $0, path: normalizedPath, fileName: normalizedName) }
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
