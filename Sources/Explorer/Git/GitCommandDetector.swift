import Foundation

/// Detects shell command strings that invoke mutating `git` subcommands.
enum GitCommandDetector {
    private static let mutatingSubcommands: [String] = [
        "add", "am", "apply", "checkout", "cherry-pick", "clean", "commit",
        "fetch", "init", "merge", "mv", "pull", "push", "rebase", "reset",
        "restore", "revert", "rm", "stash", "switch",
    ]

    private static let subcommandPattern: NSRegularExpression? = {
        let alternatives = mutatingSubcommands
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let pattern = #"^git(?:\s+(?:-(?:C|[A-Za-z][\w-]*)(?:=\S+|\s+\S+)?|[^\s;|&]+))*?\s+(?:\#(alternatives))(?:\s|$|[;|&])"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    static func mutatesWorkingTree(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        return commandSegments(trimmed).contains { segment in
            let effective = effectiveCommand(segment)
            guard effective.lowercased().hasPrefix("git") else { return false }
            guard let subcommandPattern else { return false }
            let range = NSRange(effective.startIndex..<effective.endIndex, in: effective)
            return subcommandPattern.firstMatch(in: effective, options: [], range: range) != nil
        }
    }

    private static func commandSegments(_ command: String) -> [String] {
        command
            .components(separatedBy: CharacterSet(charactersIn: ";\n"))
            .flatMap { $0.components(separatedBy: "&&") }
            .flatMap { $0.components(separatedBy: "||") }
            .flatMap { $0.components(separatedBy: "|") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func effectiveCommand(_ segment: String) -> String {
        var remainder = segment.trimmingCharacters(in: .whitespacesAndNewlines)

        while !remainder.isEmpty {
            if remainder.lowercased().hasPrefix("cd ") {
                remainder = String(remainder.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                remainder = skipShellToken(remainder)
                remainder = skipChainingOperator(remainder)
                continue
            }

            if let equalsIndex = remainder.firstIndex(of: "="),
               equalsIndex > remainder.startIndex,
               remainder[..<equalsIndex].allSatisfy({ $0.isLetter || $0 == "_" || $0.isNumber || $0 == "-" }) {
                remainder = String(remainder[remainder.index(after: equalsIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            break
        }

        return remainder
    }

    private static func skipShellToken(_ value: String) -> String {
        let remainder = value
        guard !remainder.isEmpty else { return remainder }

        if remainder.first == "\"" {
            var index = remainder.index(after: remainder.startIndex)
            while index < remainder.endIndex {
                if remainder[index] == "\"" && remainder[remainder.index(before: index)] != "\\" {
                    return String(remainder[remainder.index(after: index)...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                index = remainder.index(after: index)
            }
            return ""
        }

        if remainder.first == "'" {
            if let closing = remainder.dropFirst().firstIndex(of: "'") {
                return String(remainder[remainder.index(after: closing)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }

        if let space = remainder.firstIndex(where: { $0.isWhitespace }) {
            return String(remainder[space...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
    }

    private static func skipChainingOperator(_ value: String) -> String {
        var remainder = value
        if remainder.hasPrefix("&&") {
            remainder = String(remainder.dropFirst(2))
        } else if remainder.hasPrefix("||") {
            remainder = String(remainder.dropFirst(2))
        } else if remainder.hasPrefix(";") {
            remainder = String(remainder.dropFirst(1))
        }
        return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
