import Foundation

enum ArchivePreviewLoader {
    enum LoaderError: LocalizedError {
        case emptyListing
        case timedOut

        var errorDescription: String? {
            switch self {
            case .emptyListing: return L10n.Error.Archive.emptyListing
            case .timedOut: return L10n.Error.Archive.timedOut
            }
        }
    }

    /// 使用 bsdtar 列出 ZIP（正确处理 UTF-8 / GBK 等文件名；`unzip -l` 会把中文显示成 `?`）。
    static func listZipEntries(
        at url: URL,
        maxEntries: Int = 1_000,
        timeoutSeconds: Int = 8
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        let output = try await runTarVerboseList(url: url, maxLines: maxEntries * 2 + 60, timeoutSeconds: timeoutSeconds)
        var entries: [ArchiveEntryPreview] = []
        for rawLine in output.split(whereSeparator: \.isNewline) {
            if entries.count >= maxEntries { break }
            let line = String(rawLine)
            if line.hasPrefix("tar:") { continue }
            guard let entry = parseTarVerboseListingLine(line) else { continue }
            entries.append(entry)
        }
        guard !entries.isEmpty else { throw LoaderError.emptyListing }
        return (entries, entries.count >= maxEntries)
    }

    static func isArchiveFileName(_ lowercasedName: String) -> Bool {
        lowercasedName.hasSuffix(".zip")
            || lowercasedName.hasSuffix(".tar")
            || lowercasedName.hasSuffix(".tar.gz")
            || lowercasedName.hasSuffix(".tgz")
    }

    static func listArchiveEntries(
        at url: URL,
        maxEntries: Int = 1_000,
        timeoutSeconds: Int = 8
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        let lowerName = url.lastPathComponent.lowercased()
        if lowerName.hasSuffix(".zip") {
            return try await listZipEntries(at: url, maxEntries: maxEntries, timeoutSeconds: timeoutSeconds)
        }
        if lowerName.hasSuffix(".tar") || lowerName.hasSuffix(".tar.gz") || lowerName.hasSuffix(".tgz") {
            return try await listPlainTarEntries(at: url, maxEntries: maxEntries, timeoutSeconds: timeoutSeconds)
        }
        throw LoaderError.emptyListing
    }

    static func listPlainTarEntries(
        at url: URL,
        maxEntries: Int = 1_000,
        timeoutSeconds: Int = 8
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        let output = try await runPlainTarList(
            url: url,
            maxLines: maxEntries + 80,
            timeoutSeconds: timeoutSeconds
        )
        var entries: [ArchiveEntryPreview] = []
        for rawLine in output.split(whereSeparator: \.isNewline) {
            if entries.count >= maxEntries { break }
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("tar:") { continue }
            entries.append(.init(path: line, isDirectory: line.hasSuffix("/"), size: nil))
        }
        guard !entries.isEmpty else { throw LoaderError.emptyListing }
        return (entries, entries.count >= maxEntries)
    }

    /// 解析 `tar -tvf` 单行：`perms links user group size Mon DD HH:MM path`
    static func parseTarVerboseListingLine(_ line: String) -> ArchiveEntryPreview? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let tokens = trimmed.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        guard tokens.count >= 9 else { return nil }

        let permissions = tokens[0]
        guard permissions.first == "d" || permissions.first == "-" || permissions.first == "l" else { return nil }
        guard let size = Int64(tokens[4]) else { return nil }

        let path = decodeTarEscapedPath(tokens.dropFirst(8).joined(separator: " "))
        guard !path.isEmpty else { return nil }

        let isDirectory = permissions.hasPrefix("d") || path.hasSuffix("/")
        return ArchiveEntryPreview(
            path: path,
            isDirectory: isDirectory,
            size: isDirectory ? nil : size
        )
    }

    /// 将 `tar` 在 `LANG=C` 下输出的 `\345\237\272` 形式还原为 UTF-8 路径。
    static func decodeTarEscapedPath(_ path: String) -> String {
        guard path.contains("\\") else { return path }

        var bytes = [UInt8]()
        var index = path.startIndex
        while index < path.endIndex {
            let char = path[index]
            if char == "\\" {
                var cursor = path.index(after: index)
                var digits = ""
                while cursor < path.endIndex, digits.count < 3 {
                    let next = path[cursor]
                    guard next >= "0", next <= "7" else { break }
                    digits.append(next)
                    cursor = path.index(after: cursor)
                }
                if let byte = UInt8(digits, radix: 8) {
                    bytes.append(byte)
                    index = cursor
                    continue
                }
            }
            bytes.append(contentsOf: String(char).utf8)
            index = path.index(after: index)
        }
        return String(bytes: bytes, encoding: .utf8) ?? path
    }

    private static func runTarVerboseList(url: URL, maxLines: Int, timeoutSeconds: Int) async throws -> String {
        try await runShellCommand(
            "/usr/bin/tar -tvf \(ShellQuoting.singleQuote(url.path)) 2>&1 | /usr/bin/head -n \(maxLines)",
            timeoutSeconds: timeoutSeconds
        )
    }

    private static func runPlainTarList(url: URL, maxLines: Int, timeoutSeconds: Int) async throws -> String {
        try await runShellCommand(
            "/usr/bin/tar -tf \(ShellQuoting.singleQuote(url.path)) 2>&1 | /usr/bin/head -n \(maxLines)",
            timeoutSeconds: timeoutSeconds
        )
    }

    private static func runShellCommand(_ command: String, timeoutSeconds: Int) async throws -> String {
        do {
            return try await ShellProcessRunner.runCommand(command, timeoutSeconds: timeoutSeconds)
        } catch ShellProcessRunner.RunnerError.timedOut {
            throw LoaderError.timedOut
        }
    }

}
