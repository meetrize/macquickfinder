import Foundation

struct OperationShellTranslationOptions: Equatable {
    var includeStepComments: Bool = false
    var generalizePaths: Bool = false
}

enum OperationShellTranslator {
    static func translate(
        steps: [RecordedOperationStep],
        options: OperationShellTranslationOptions = OperationShellTranslationOptions()
    ) -> String {
        let operations = steps.filter(\.isIncluded).map(\.operation)
        guard !operations.isEmpty else { return "" }

        var lines: [String] = []
        var index = 0
        var stepNumber = 1

        while index < operations.count {
            let operation = operations[index]

            if index + 1 < operations.count {
                if case .copy(let sources) = operation,
                   case .paste(let pairs, .copy) = operations[index + 1],
                   sourcesMatch(sources, pairs: pairs) {
                    appendStepComment(&lines, number: stepNumber, options: options)
                    lines.append(contentsOf: copyCommands(for: pairs))
                    index += 2
                    stepNumber += 1
                    continue
                }

                if case .cut(let sources) = operation,
                   case .paste(let pairs, .move) = operations[index + 1],
                   sourcesMatch(sources, pairs: pairs) {
                    appendStepComment(&lines, number: stepNumber, options: options)
                    lines.append(contentsOf: moveCommands(for: pairs))
                    index += 2
                    stepNumber += 1
                    continue
                }
            }

            appendStepComment(&lines, number: stepNumber, options: options)
            lines.append(contentsOf: commandLines(for: operation))
            index += 1
            stepNumber += 1
        }

        return lines.joined(separator: "\n")
    }

    private static func sourcesMatch(_ sources: [URL], pairs: [RecordedFilePair]) -> Bool {
        let recordedSources = sources.map { $0.standardizedFileURL.path }
        let pasteSources = pairs.map { $0.source.standardizedFileURL.path }
        return recordedSources == pasteSources
    }

    private static func appendStepComment(
        _ lines: inout [String],
        number: Int,
        options: OperationShellTranslationOptions
    ) {
        guard options.includeStepComments else { return }
        lines.append("# step \(number):")
    }

    private static func commandLines(for operation: RecordedOperation) -> [String] {
        switch operation {
        case .copy, .cut:
            return []
        case .paste(let pairs, let mode):
            switch mode {
            case .copy: return copyCommands(for: pairs)
            case .move: return moveCommands(for: pairs)
            }
        case .transferItems(let pairs, let mode):
            switch mode {
            case .copy: return copyCommands(for: pairs)
            case .move: return moveCommands(for: pairs)
            }
        case .trash(let urls):
            return urls.map { trashCommand(for: $0) }
        case .deleteImmediately(let urls):
            return urls.map { "/bin/rm -rf \(quotePath($0.path))" }
        case .rename(let source, let destination):
            return ["/bin/mv \(quotePath(source.path)) \(quotePath(destination.path))"]
        case .createDirectory(let url):
            return ["/bin/mkdir -p \(quotePath(url.path))"]
        case .createFile(let url):
            return ["/usr/bin/touch \(quotePath(url.path))"]
        }
    }

    private static func copyCommands(for pairs: [RecordedFilePair]) -> [String] {
        pairs.map { pair in
            "/bin/cp -R \(quotePath(pair.source.path)) \(quotePath(pair.destination.path))"
        }
    }

    private static func moveCommands(for pairs: [RecordedFilePair]) -> [String] {
        pairs.map { pair in
            "/bin/mv \(quotePath(pair.source.path)) \(quotePath(pair.destination.path))"
        }
    }

    private static func trashCommand(for url: URL) -> String {
        let escaped = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "/usr/bin/osascript -e 'tell application \"Finder\" to delete POSIX file \"\(escaped)\"'"
    }

    private static func quotePath(_ path: String) -> String {
        ShellQuoting.singleQuote((path as NSString).standardizingPath)
    }
}
