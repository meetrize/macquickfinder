import Foundation

struct OperationPathGeneralizer {
    let recordingCWD: String
    let primarySources: [URL]

    init(recordingCWD: String, operations: [RecordedOperation]) {
        self.recordingCWD = Self.standardize(recordingCWD)
        self.primarySources = OperationShellTranslator.primarySources(from: operations)
    }

    func pathToken(for path: String) -> String {
        let standardized = Self.standardize(path)
        if standardized == recordingCWD {
            return "%d"
        }

        if primarySources.count == 1,
           standardized == Self.standardize(primarySources[0].path) {
            return "%p"
        }

        if standardized.hasPrefix(recordingCWD + "/") {
            let relative = String(standardized.dropFirst(recordingCWD.count + 1))
            if !relative.isEmpty, !relative.contains("/") {
                return "'%d/\(relative)'"
            }
        }

        return ShellQuoting.singleQuote(standardized)
    }

    func sourcesToken(for sources: [URL]) -> String {
        let standardizedSources = Set(sources.map { Self.standardize($0.path) })
        let primary = Set(primarySources.map { Self.standardize($0.path) })
        guard standardizedSources == primary, !primary.isEmpty else {
            return sources.map { pathToken(for: $0.path) }.joined(separator: " ")
        }
        switch primarySources.count {
        case 1:
            return "%p"
        default:
            return "%P"
        }
    }

    func pairDestinationToken(source: URL, destination: URL) -> String {
        let destPath = Self.standardize(destination.path)
        let sourcePath = Self.standardize(source.path)

        if primarySources.count == 1,
           sourcePath == Self.standardize(primarySources[0].path),
           destPath.hasPrefix(recordingCWD + "/") {
            let relative = String(destPath.dropFirst(recordingCWD.count + 1))
            if !relative.isEmpty {
                return "'%d/\(relative)'"
            }
        }

        return pathToken(for: destPath)
    }

    private static func standardize(_ path: String) -> String {
        (path as NSString).standardizingPath
    }
}
