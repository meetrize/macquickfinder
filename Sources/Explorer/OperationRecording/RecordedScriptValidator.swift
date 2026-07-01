import Foundation

enum RecordedScriptValidationLevel: Equatable {
    case error
    case warning
}

struct RecordedScriptValidationIssue: Identifiable, Equatable {
    let id = UUID()
    let level: RecordedScriptValidationLevel
    let message: String
}

struct RecordedScriptValidationResult: Equatable {
    let issues: [RecordedScriptValidationIssue]

    var hasErrors: Bool {
        issues.contains { $0.level == .error }
    }

    var isSuccessful: Bool {
        issues.isEmpty
    }
}

enum RecordedScriptValidator {
    static func validate(content: String, recordingCWD: String) -> RecordedScriptValidationResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        var issues: [RecordedScriptValidationIssue] = []

        guard !trimmed.isEmpty else {
            issues.append(makeError(L10n.OperationRecording.Validation.emptyScript))
            return RecordedScriptValidationResult(issues: issues)
        }

        for token in unknownVariables(in: trimmed) {
            issues.append(makeError(L10n.OperationRecording.Validation.unsupportedVariable(token)))
        }
        if issues.contains(where: { $0.level == .error }) {
            return RecordedScriptValidationResult(issues: issues)
        }

        let mockContext = makeMockContext(cwd: recordingCWD)
        let expanded: String
        do {
            expanded = try SnippetExpander.expand(trimmed, context: mockContext, scriptType: .shell)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            issues.append(makeError(L10n.OperationRecording.Validation.variableExpansion(message)))
            return RecordedScriptValidationResult(issues: issues)
        }

        if let syntaxError = validateShellSyntax(expanded) {
            issues.append(makeError(L10n.OperationRecording.Validation.shellSyntax(syntaxError)))
        }

        for warning in SnippetShellSecurityChecker.securityWarnings(for: trimmed) {
            issues.append(RecordedScriptValidationIssue(level: .warning, message: warning.message))
        }

        return RecordedScriptValidationResult(issues: issues)
    }

    static func unknownVariables(in content: String) -> [String] {
        let supported = SnippetVariableCatalog.supportedTokens
        var unknown: [String] = []
        var seen = Set<String>()
        var index = content.startIndex

        while index < content.endIndex {
            guard content[index] == "%" else {
                index = content.index(after: index)
                continue
            }

            guard let token = matchedToken(in: content, at: index, supported: supported) else {
                var end = content.index(after: index)
                while end < content.endIndex {
                    let character = content[end]
                    if character.isLetter || character.isNumber {
                        end = content.index(after: end)
                    } else {
                        break
                    }
                }
                let unknownToken = String(content[index..<end])
                if seen.insert(unknownToken).inserted {
                    unknown.append(unknownToken)
                }
                index = end
                continue
            }

            index = content.index(index, offsetBy: token.count)
        }

        return unknown
    }

    private static func matchedToken(in content: String, at index: String.Index, supported: [String]) -> String? {
        for token in supported where content[index...].hasPrefix(token) {
            return token
        }
        return nil
    }

    private static func validateShellSyntax(_ script: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: SnippetDefaults.shellInterpreter)
        process.arguments = ["-n", "-c", script]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return error.localizedDescription
        }

        guard process.terminationStatus != 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return message?.isEmpty == false ? message : L10n.OperationRecording.Validation.invalidShell
    }

    private static func makeMockContext(cwd: String) -> SnippetExecutionContext {
        let standardizedCWD = SnippetExpander.standardize(cwd.isEmpty ? "/tmp" : cwd)
        let samplePath = (standardizedCWD as NSString).appendingPathComponent("sample.txt")
        let sampleURL = URL(fileURLWithPath: samplePath)
        let sampleFile = FileItem(
            id: samplePath,
            url: sampleURL,
            name: sampleURL.lastPathComponent,
            isDirectory: false,
            modificationDate: Date(),
            creationDate: Date(),
            size: 1,
            isHidden: false,
            fileType: sampleURL.pathExtension,
            sizeDisplay: "1",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        return SnippetExecutionContext(cwd: standardizedCWD, selectedItems: [sampleFile])
    }

    private static func makeError(_ message: String) -> RecordedScriptValidationIssue {
        RecordedScriptValidationIssue(level: .error, message: message)
    }
}
