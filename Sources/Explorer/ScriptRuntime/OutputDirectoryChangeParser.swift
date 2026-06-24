import Foundation

/// 解析输出面板命令行里开头的 `cd` 链，用于同步主窗口地址栏。
enum OutputDirectoryChangeParser {
    /// 若命令以 `cd` / `cd … && …` 开头且目标目录存在，返回解析后的绝对路径。
    static func resolveLeadingDirectoryChange(
        expandedCommand: String,
        currentDirectory: String,
        previousDirectory: String?
    ) -> String? {
        var cwd = SnippetExpander.standardize(currentDirectory)
        var changed = false

        for segment in commandSegments(expandedCommand) {
            guard let target = cdTarget(from: segment) else { break }
            guard let resolved = resolveCDTarget(
                target,
                currentDirectory: cwd,
                previousDirectory: previousDirectory
            ) else {
                break
            }
            cwd = resolved
            changed = true
        }

        guard changed, isExistingDirectory(cwd) else { return nil }
        return cwd
    }

    private static func commandSegments(_ command: String) -> [String] {
        command
            .replacingOccurrences(of: ";", with: "&&")
            .split(separator: "&&", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// `nil` = 非 cd；`.some(nil)` = 裸 `cd`（回主目录）；`.some("arg")` = 带参数。
    private static func cdTarget(from segment: String) -> String?? {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "cd" || trimmed.hasPrefix("cd ") else { return nil }
        if trimmed == "cd" {
            return .some(nil)
        }
        let argument = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !argument.isEmpty else { return .some(nil) }
        return .some(unquote(argument))
    }

    private static func resolveCDTarget(
        _ target: String?,
        currentDirectory: String,
        previousDirectory: String?
    ) -> String? {
        if let target {
            if target == "-" {
                guard let previousDirectory else { return nil }
                return SnippetExpander.standardize(previousDirectory)
            }
            let expanded = (target as NSString).expandingTildeInPath
            if expanded.hasPrefix("/") {
                return SnippetExpander.standardize(expanded)
            }
            return SnippetExpander.standardize(
                (currentDirectory as NSString).appendingPathComponent(expanded)
            )
        }
        return SnippetExpander.standardize(FileManager.default.homeDirectoryForCurrentUser.path)
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let first = value.first!
        let last = value.last!
        if (first == "'" && last == "'") || (first == "\"" && last == "\"") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func isExistingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
