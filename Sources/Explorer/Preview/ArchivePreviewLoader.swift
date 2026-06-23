import Foundation

enum ArchivePreviewLoader {
    enum LoaderError: LocalizedError {
        case emptyListing
        case timedOut

        var errorDescription: String? {
            switch self {
            case .emptyListing: return "无法读取 ZIP 目录"
            case .timedOut: return "目录读取超时"
            }
        }
    }

    /// 使用 bsdtar 列出 ZIP（正确处理 UTF-8 / GBK 等文件名；`unzip -l` 会把中文显示成 `?`）。
    static func listZipEntries(
        at url: URL,
        maxEntries: Int = 1_000,
        timeoutSeconds: Int = 8
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        let output = try await runTarList(url: url, maxLines: maxEntries * 2 + 60, timeoutSeconds: timeoutSeconds)
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

    /// 解析 `tar -tvf` 单行：`perms links user group size Mon DD HH:MM path`
    static func parseTarVerboseListingLine(_ line: String) -> ArchiveEntryPreview? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let tokens = trimmed.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        guard tokens.count >= 9 else { return nil }

        let permissions = tokens[0]
        guard permissions.first == "d" || permissions.first == "-" || permissions.first == "l" else { return nil }
        guard let size = Int64(tokens[4]) else { return nil }

        let path = tokens.dropFirst(8).joined(separator: " ")
        guard !path.isEmpty else { return nil }

        let isDirectory = permissions.hasPrefix("d") || path.hasSuffix("/")
        return ArchiveEntryPreview(
            path: path,
            isDirectory: isDirectory,
            size: isDirectory ? nil : size
        )
    }

    private static func runTarList(url: URL, maxLines: Int, timeoutSeconds: Int) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "/usr/bin/tar -tvf \(shellEscape(url.path)) 2>&1 | /usr/bin/head -n \(maxLines)",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()

        let start = Date()
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                throw CancellationError()
            }
            if Date().timeIntervalSince(start) > Double(timeoutSeconds) {
                process.terminate()
                throw LoaderError.timedOut
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
