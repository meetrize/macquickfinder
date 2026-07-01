import Foundation

struct SnippetShellSecurityWarning: Equatable, Identifiable {
    let id = UUID()
    let message: String
}

enum SnippetShellSecurityChecker {
    private struct Rule {
        let matches: (_ lowered: String, _ original: String) -> Bool
        let message: () -> String
    }

    private static let destructivePatterns = [
        "rm -rf", "rm -r", "rm ", "mv ", "mkfs", "dd if=",
    ]

    static func isDestructive(_ content: String) -> Bool {
        let lowered = content.lowercased()
        return destructivePatterns.contains { lowered.contains($0) }
    }

    static func securityWarnings(for content: String) -> [SnippetShellSecurityWarning] {
        let lowered = content.lowercased()
        var warnings: [SnippetShellSecurityWarning] = []
        var seenMessages = Set<String>()

        for rule in rules where rule.matches(lowered, content) {
            let message = rule.message()
            guard seenMessages.insert(message).inserted else { continue }
            warnings.append(SnippetShellSecurityWarning(message: message))
        }

        return warnings
    }

    private static let rules: [Rule] = [
        Rule(matches: { lowered, _ in lowered.contains("rm -rf") }, message: { L10n.OperationRecording.Security.rmRf }),
        Rule(matches: { lowered, _ in lowered.contains("rm -r") }, message: { L10n.OperationRecording.Security.rmR }),
        Rule(matches: { lowered, _ in lowered.contains("rm ") }, message: { L10n.OperationRecording.Security.rm }),
        Rule(matches: { lowered, _ in lowered.contains("mv ") }, message: { L10n.OperationRecording.Security.mv }),
        Rule(matches: { lowered, _ in lowered.contains("mkfs") }, message: { L10n.OperationRecording.Security.mkfs }),
        Rule(matches: { lowered, _ in lowered.contains("dd if=") }, message: { L10n.OperationRecording.Security.dd }),
        Rule(matches: { lowered, _ in lowered.contains("sudo ") }, message: { L10n.OperationRecording.Security.sudo }),
        Rule(matches: { lowered, _ in lowered.contains("eval ") }, message: { L10n.OperationRecording.Security.eval }),
        Rule(matches: { lowered, _ in lowered.contains("chmod 777") }, message: { L10n.OperationRecording.Security.chmod777 }),
        Rule(matches: { lowered, _ in lowered.contains("chmod -r 777") }, message: { L10n.OperationRecording.Security.chmod777Recursive }),
        Rule(matches: { lowered, _ in lowered.contains("> /dev/") }, message: { L10n.OperationRecording.Security.writeDev }),
        Rule(
            matches: { lowered, original in lowered.contains("curl") && original.contains("|") },
            message: { L10n.OperationRecording.Security.curlPipe }
        ),
        Rule(
            matches: { lowered, original in lowered.contains("wget") && original.contains("|") },
            message: { L10n.OperationRecording.Security.wgetPipe }
        ),
    ]
}
