import Foundation

enum SnippetRecordingDraftBuilder {
    static func build(
        steps: [RecordedOperationStep],
        script: String,
        recordingCWD: String
    ) -> SnippetRecordingDraft {
        let included = steps.filter(\.isIncluded)
        let operations = included.map(\.operation)
        return SnippetRecordingDraft(
            suggestedName: suggestName(from: included),
            suggestedScope: inferScope(from: operations, recordingCWD: recordingCWD),
            content: script
        )
    }

    static func suggestName(from steps: [RecordedOperationStep]) -> String {
        var seen = Set<String>()
        var unique: [String] = []
        for step in steps {
            let title = shortTitle(for: step.operation)
            guard !title.isEmpty, !seen.contains(title) else { continue }
            seen.insert(title)
            unique.append(title)
        }
        let joined = unique.prefix(3).joined(separator: " · ")
        guard !joined.isEmpty else {
            return L10n.OperationRecording.defaultSnippetName
        }
        return L10n.OperationRecording.recordingName(joined)
    }

    private static func shortTitle(for operation: RecordedOperation) -> String {
        switch operation {
        case .copy, .cut:
            return ""
        default:
            return RecordedOperationSummary.shortTitle(for: operation)
        }
    }

    static func scopeLabel(for scope: SnippetScope) -> String {
        switch scope {
        case .fileExtensions(let extensions):
            let formatted = extensions.map { ".\($0)" }.joined(separator: ", ")
            return "\(SnippetScopeKind.fileExtensions.displayName) (\(formatted))"
        default:
            return scope.kind.displayName
        }
    }

    static func inferScope(from operations: [RecordedOperation], recordingCWD: String) -> SnippetScope {
        guard !operations.isEmpty else { return .global }

        let onlyCreation = operations.allSatisfy { operation in
            switch operation {
            case .createDirectory, .createFile:
                return true
            default:
                return false
            }
        }
        if onlyCreation {
            return .anytime
        }

        let sources = OperationShellTranslator.primarySources(from: operations)
        if sources.isEmpty {
            return .global
        }

        if sources.count == 1 {
            return .singleSelection
        }

        let kinds = sources.map(sourceKind(for:))
        let allFiles = kinds.allSatisfy { $0 == .file }
        let allDirectories = kinds.allSatisfy { $0 == .directory }

        if allFiles {
            let extensions = Set(
                sources
                    .map { $0.pathExtension.lowercased() }
                    .filter { !$0.isEmpty }
            )
            if extensions.count == 1, let ext = extensions.first {
                return .fileExtensions([ext])
            }
            return .filesOnly
        }

        if allDirectories {
            return .directoriesOnly
        }

        return .global
    }

    private enum SourceKind {
        case file
        case directory
        case unknown
    }

    private static func sourceKind(for url: URL) -> SourceKind {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return url.pathExtension.isEmpty ? .unknown : .file
        }
        return isDirectory.boolValue ? .directory : .file
    }
}
