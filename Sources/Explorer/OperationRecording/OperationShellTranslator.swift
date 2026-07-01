import Foundation

struct OperationShellTranslationOptions: Equatable {
    var includeStepComments: Bool = false
    var generalizePaths: Bool = false
    var recordingCWD: String?
}

enum OperationShellTranslator {
    static func translate(
        steps: [RecordedOperationStep],
        options: OperationShellTranslationOptions = OperationShellTranslationOptions()
    ) -> String {
        let includedSteps = steps.filter(\.isIncluded)
        let operations = includedSteps.map(\.operation)
        guard !operations.isEmpty else { return "" }

        let generalizer: OperationPathGeneralizer? = {
            guard options.generalizePaths, let cwd = options.recordingCWD, !cwd.isEmpty else {
                return nil
            }
            return OperationPathGeneralizer(recordingCWD: cwd, operations: operations)
        }()

        var lines: [String] = []
        if options.generalizePaths, let cwd = options.recordingCWD, !cwd.isEmpty {
            lines.append("# cwd: \(cwd)")
        }

        var index = 0
        var stepNumber = 1

        while index < operations.count {
            let operation = operations[index]

            if index + 1 < operations.count {
                if case .copy(let sources) = operation,
                   case .paste(let pairs, .copy) = operations[index + 1],
                   sourcesMatch(sources, pairs: pairs) {
                    appendStepComment(&lines, number: stepNumber, options: options)
                    lines.append(contentsOf: copyCommands(for: pairs, generalizer: generalizer))
                    index += 2
                    stepNumber += 1
                    continue
                }

                if case .cut(let sources) = operation,
                   case .paste(let pairs, .move) = operations[index + 1],
                   sourcesMatch(sources, pairs: pairs) {
                    appendStepComment(&lines, number: stepNumber, options: options)
                    lines.append(contentsOf: moveCommands(for: pairs, generalizer: generalizer))
                    index += 2
                    stepNumber += 1
                    continue
                }
            }

            appendStepComment(&lines, number: stepNumber, options: options)
            lines.append(contentsOf: commandLines(for: operation, generalizer: generalizer))
            index += 1
            stepNumber += 1
        }

        return lines.joined(separator: "\n")
    }

    static func primarySources(from operations: [RecordedOperation]) -> [URL] {
        for operation in operations {
            if case .copy(let sources) = operation {
                return uniqueURLs(sources)
            }
            if case .cut(let sources) = operation {
                return uniqueURLs(sources)
            }
        }

        var urls: [URL] = []
        for operation in operations {
            switch operation {
            case .paste(let pairs, _), .transferItems(let pairs, _):
                urls.append(contentsOf: pairs.map(\.source))
            case .trash(let items), .deleteImmediately(let items):
                urls.append(contentsOf: items)
            case .rename(let source, _):
                urls.append(source)
            case .compress(let sources, _, _):
                urls.append(contentsOf: sources)
            case .extract(let archive, _, _):
                urls.append(archive)
            default:
                break
            }
        }
        return uniqueURLs(urls)
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { continue }
            seen.insert(path)
            result.append(url)
        }
        return result
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

    private static func commandLines(
        for operation: RecordedOperation,
        generalizer: OperationPathGeneralizer?
    ) -> [String] {
        switch operation {
        case .copy, .cut:
            return []
        case .paste(let pairs, let mode):
            switch mode {
            case .copy: return copyCommands(for: pairs, generalizer: generalizer)
            case .move: return moveCommands(for: pairs, generalizer: generalizer)
            }
        case .transferItems(let pairs, let mode):
            switch mode {
            case .copy: return copyCommands(for: pairs, generalizer: generalizer)
            case .move: return moveCommands(for: pairs, generalizer: generalizer)
            }
        case .trash(let urls):
            return trashCommands(for: urls, generalizer: generalizer)
        case .deleteImmediately(let urls):
            return urls.map { url in
                "/bin/rm -rf \(quotedPath(url.path, generalizer: generalizer))"
            }
        case .rename(let source, let destination):
            if let generalizer {
                return [
                    "/bin/mv \(generalizer.pathToken(for: source.path)) \(generalizer.pairDestinationToken(source: source, destination: destination))",
                ]
            }
            return ["/bin/mv \(literalPath(source.path)) \(literalPath(destination.path))"]
        case .createDirectory(let url):
            return ["/bin/mkdir -p \(quotedPath(url.path, generalizer: generalizer))"]
        case .createFile(let url):
            return ["/usr/bin/touch \(quotedPath(url.path, generalizer: generalizer))"]
        case .compress(_, _, let command), .extract(_, _, let command):
            return [command]
        }
    }

    private static func copyCommands(
        for pairs: [RecordedFilePair],
        generalizer: OperationPathGeneralizer?
    ) -> [String] {
        guard let generalizer else {
            return pairs.map {
                "/bin/cp -R \(literalPath($0.source.path)) \(literalPath($0.destination.path))"
            }
        }

        let sources = pairs.map(\.source)
        if pairs.count > 1, Set(sources.map(\.path)) == Set(generalizer.primarySources.map(\.path)) {
            let destination = pairs[0].destination
            return [
                "/bin/cp -R %P \(generalizer.pairDestinationToken(source: sources[0], destination: destination))",
            ]
        }

        return pairs.map { pair in
            "/bin/cp -R \(generalizer.pathToken(for: pair.source.path)) \(generalizer.pairDestinationToken(source: pair.source, destination: pair.destination))"
        }
    }

    private static func moveCommands(
        for pairs: [RecordedFilePair],
        generalizer: OperationPathGeneralizer?
    ) -> [String] {
        guard let generalizer else {
            return pairs.map {
                "/bin/mv \(literalPath($0.source.path)) \(literalPath($0.destination.path))"
            }
        }

        let sources = pairs.map(\.source)
        if pairs.count > 1, Set(sources.map(\.path)) == Set(generalizer.primarySources.map(\.path)) {
            let destination = pairs[0].destination
            return [
                "/bin/mv %P \(generalizer.pairDestinationToken(source: sources[0], destination: destination))",
            ]
        }

        return pairs.map { pair in
            "/bin/mv \(generalizer.pathToken(for: pair.source.path)) \(generalizer.pairDestinationToken(source: pair.source, destination: pair.destination))"
        }
    }

    private static func trashCommands(
        for urls: [URL],
        generalizer: OperationPathGeneralizer?
    ) -> [String] {
        if let generalizer, urls.count == 1,
           generalizer.primarySources.count == 1,
           urls[0].standardizedFileURL.path == generalizer.primarySources[0].standardizedFileURL.path {
            return [
                "/usr/bin/osascript -e 'tell application \"Finder\" to delete POSIX file %p'",
            ]
        }

        if let generalizer, urls.count > 1,
           Set(urls.map(\.path)) == Set(generalizer.primarySources.map(\.path)) {
            return ["# TODO: trash multiple items — use %P or repeat per item"]
        }

        return urls.map { trashCommand(for: $0) }
    }

    private static func trashCommand(for url: URL) -> String {
        let escaped = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "/usr/bin/osascript -e 'tell application \"Finder\" to delete POSIX file \"\(escaped)\"'"
    }

    private static func quotedPath(_ path: String, generalizer: OperationPathGeneralizer?) -> String {
        if let generalizer {
            return generalizer.pathToken(for: path)
        }
        return literalPath(path)
    }

    private static func literalPath(_ path: String) -> String {
        ShellQuoting.singleQuote((path as NSString).standardizingPath)
    }
}
