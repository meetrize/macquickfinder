import Foundation

/// 通过 `lsar` / `7zz` 列出 `.rar` 等 bsdtar 不支持的归档（方案 B：系统 CLI，零包体积增量）。
enum ArchiveAlternateListing {
    static let sevenZipCandidatePaths = [
        "/opt/homebrew/bin/7zz",
        "/opt/homebrew/bin/7zr",
        "/opt/homebrew/bin/7z",
        "/usr/local/bin/7zz",
        "/usr/local/bin/7zr",
        "/usr/local/bin/7z",
    ]

    static let lsarCandidatePaths = [
        "/opt/homebrew/bin/lsar",
        "/usr/local/bin/lsar",
        "/opt/homebrew/bin/unar",
        "/usr/local/bin/unar",
    ]

    static func listEntries(
        at url: URL,
        detail: ArchiveListingDetail,
        maxEntries: Int,
        timeoutSeconds: Int
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        if let lsar = resolveLSAR() {
            return try await listWithLSAR(
                at: url,
                lsar: lsar,
                detail: detail,
                maxEntries: maxEntries,
                timeoutSeconds: timeoutSeconds
            )
        }
        if let sevenZip = resolveSevenZip() {
            return try await listWithSevenZipSLT(
                at: url,
                sevenZip: sevenZip,
                detail: detail,
                maxEntries: maxEntries,
                timeoutSeconds: timeoutSeconds
            )
        }
        throw ArchivePreviewLoader.LoaderError.unsupportedFormat
    }

    static func streamEntries(
        at url: URL,
        maxEntries: Int?,
        timeoutSeconds: Int,
        batchSize: Int
    ) -> AsyncThrowingStream<ArchivePreviewLoader.ArchivePreviewStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if let lsar = resolveLSAR() {
                        try await streamWithLSAR(
                            at: url,
                            lsar: lsar,
                            maxEntries: maxEntries,
                            timeoutSeconds: timeoutSeconds,
                            batchSize: batchSize,
                            continuation: continuation
                        )
                        return
                    }
                    if let sevenZip = resolveSevenZip() {
                        try await streamWithSevenZipSLT(
                            at: url,
                            sevenZip: sevenZip,
                            maxEntries: maxEntries,
                            timeoutSeconds: timeoutSeconds,
                            batchSize: batchSize,
                            continuation: continuation
                        )
                        return
                    }
                    continuation.finish(throwing: ArchivePreviewLoader.LoaderError.unsupportedFormat)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    static func resolveLSAR() -> URL? {
        resolveExecutable(in: lsarCandidatePaths, preferredName: "lsar")
    }

    static func resolveSevenZip() -> URL? {
        resolveExecutable(in: sevenZipCandidatePaths, preferredName: "7zz")
    }

    private static func resolveExecutable(in candidates: [String], preferredName: String) -> URL? {
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        if let path = resolveViaWhich(preferredName) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private static func resolveViaWhich(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
                return nil
            }
            return path
        } catch {
            return nil
        }
    }

    private static func listWithLSAR(
        at url: URL,
        lsar: URL,
        detail: ArchiveListingDetail,
        maxEntries: Int,
        timeoutSeconds: Int
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        let output = try await runProcess(
            executable: lsar,
            arguments: ["-j", url.path],
            timeoutSeconds: timeoutSeconds
        )
        let parsed = try parseLSARJSON(output)
        guard !parsed.isEmpty else { throw ArchivePreviewLoader.LoaderError.emptyListing }
        let limited = Array(parsed.prefix(maxEntries))
        let entries = limited.map { item in
            ArchiveEntryPreview(
                path: item.path,
                isDirectory: item.isDirectory,
                size: detail == .verbose && !item.isDirectory ? item.size : nil
            )
        }
        return (entries, parsed.count > maxEntries)
    }

    private static func streamWithLSAR(
        at url: URL,
        lsar: URL,
        maxEntries: Int?,
        timeoutSeconds: Int,
        batchSize: Int,
        continuation: AsyncThrowingStream<ArchivePreviewLoader.ArchivePreviewStreamEvent, Error>.Continuation
    ) async throws {
        let output = try await runProcess(
            executable: lsar,
            arguments: ["-j", url.path],
            timeoutSeconds: timeoutSeconds
        )
        let parsed = try parseLSARJSON(output)
        guard !parsed.isEmpty else {
            continuation.finish(throwing: ArchivePreviewLoader.LoaderError.emptyListing)
            return
        }

        var batch: [ArchiveEntryPreview] = []
        var total = 0
        var truncated = false

        func flush() {
            guard !batch.isEmpty else { return }
            continuation.yield(.batch(batch))
            batch = []
        }

        for item in parsed {
            try Task.checkCancellation()
            if let maxEntries, total >= maxEntries {
                truncated = true
                break
            }
            batch.append(
                ArchiveEntryPreview(
                    path: item.path,
                    isDirectory: item.isDirectory,
                    size: nil
                )
            )
            total += 1
            if batch.count >= batchSize {
                flush()
            }
        }
        flush()
        continuation.yield(.finished(truncated: truncated, timedOut: false))
        continuation.finish()
    }

    private static func listWithSevenZipSLT(
        at url: URL,
        sevenZip: URL,
        detail: ArchiveListingDetail,
        maxEntries: Int,
        timeoutSeconds: Int
    ) async throws -> (entries: [ArchiveEntryPreview], truncated: Bool) {
        let output = try await runProcess(
            executable: sevenZip,
            arguments: ["l", "-slt", "-r", url.path],
            timeoutSeconds: timeoutSeconds
        )
        let parsed = parseSevenZipSLT(output)
        guard !parsed.isEmpty else { throw ArchivePreviewLoader.LoaderError.emptyListing }
        let limited = Array(parsed.prefix(maxEntries))
        let entries = limited.map { item in
            ArchiveEntryPreview(
                path: item.path,
                isDirectory: item.isDirectory,
                size: detail == .verbose && !item.isDirectory ? item.size : nil
            )
        }
        return (entries, parsed.count > maxEntries)
    }

    private static func streamWithSevenZipSLT(
        at url: URL,
        sevenZip: URL,
        maxEntries: Int?,
        timeoutSeconds: Int,
        batchSize: Int,
        continuation: AsyncThrowingStream<ArchivePreviewLoader.ArchivePreviewStreamEvent, Error>.Continuation
    ) async throws {
        let command = "\(ShellQuoting.singleQuote(sevenZip.path)) l -slt -r \(ShellQuoting.singleQuote(url.path)) 2>&1"
        var batch: [ArchiveEntryPreview] = []
        var total = 0
        var truncated = false
        var currentPath: String?
        var currentSize: Int64?
        var currentIsDirectory = false

        func flushBatch() {
            guard !batch.isEmpty else { return }
            continuation.yield(.batch(batch))
            batch = []
        }

        func flushEntry() {
            guard let path = currentPath, !path.isEmpty else { return }
            batch.append(
                ArchiveEntryPreview(
                    path: path,
                    isDirectory: currentIsDirectory,
                    size: nil
                )
            )
            total += 1
            currentPath = nil
            currentSize = nil
            currentIsDirectory = false
            if batch.count >= batchSize {
                flushBatch()
            }
        }

        do {
            for try await rawLine in ShellProcessRunner.streamCommandLines(
                command,
                timeoutSeconds: timeoutSeconds
            ) {
                try Task.checkCancellation()
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty {
                    flushEntry()
                    if let maxEntries, total >= maxEntries {
                        truncated = true
                        break
                    }
                    continue
                }
                if line.hasPrefix("Path = ") {
                    flushEntry()
                    if let maxEntries, total >= maxEntries {
                        truncated = true
                        break
                    }
                    currentPath = String(line.dropFirst("Path = ".count))
                } else if line.hasPrefix("Size = "), let value = Int64(line.dropFirst("Size = ".count)) {
                    currentSize = value
                } else if line.hasPrefix("Attributes = ") {
                    let attrs = String(line.dropFirst("Attributes = ".count))
                    currentIsDirectory = attrs.contains("D")
                } else if line.lowercased().contains("encrypted") || line.lowercased().contains("password") {
                    throw ArchivePreviewLoader.LoaderError.encrypted
                }
                _ = currentSize
            }
            flushEntry()
            guard total > 0 else {
                continuation.finish(throwing: ArchivePreviewLoader.LoaderError.emptyListing)
                return
            }
            flushBatch()
            continuation.yield(.finished(truncated: truncated, timedOut: false))
            continuation.finish()
        } catch ShellProcessRunner.RunnerError.timedOut {
            flushEntry()
            flushBatch()
            if total > 0 {
                continuation.yield(.finished(truncated: true, timedOut: true))
                continuation.finish()
            } else {
                continuation.finish(throwing: ArchivePreviewLoader.LoaderError.timedOut)
            }
        }
    }

    private static func runProcess(
        executable: URL,
        arguments: [String],
        timeoutSeconds: Int
    ) async throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
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
                throw ArchivePreviewLoader.LoaderError.timedOut
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if isEncryptedOutput(output) {
            throw ArchivePreviewLoader.LoaderError.encrypted
        }
        if process.terminationStatus != 0, output.isEmpty {
            throw ArchivePreviewLoader.LoaderError.emptyListing
        }
        return output
    }

    private static func isEncryptedOutput(_ output: String) -> Bool {
        let lower = output.lowercased()
        return lower.contains("wrong password")
            || lower.contains("enter password")
            || lower.contains("encrypted")
            || lower.contains("can not open the file as archive")
    }

    struct ParsedEntry {
        let path: String
        let isDirectory: Bool
        let size: Int64?
    }

    static func parseLSARJSON(_ output: String) throws -> [ParsedEntry] {
        guard let data = output.data(using: .utf8) else {
            throw ArchivePreviewLoader.LoaderError.emptyListing
        }
        let object = try JSONSerialization.jsonObject(with: data)
        let items: [[String: Any]]
        if let array = object as? [[String: Any]] {
            items = array
        } else if let dict = object as? [String: Any], let contents = dict["lsarContents"] as? [[String: Any]] {
            items = contents
        } else {
            throw ArchivePreviewLoader.LoaderError.emptyListing
        }

        var entries: [ParsedEntry] = []
        entries.reserveCapacity(items.count)
        for item in items {
            let path = (item["XADFileName"] as? String)
                ?? (item["XADLastPathComponent"] as? String)
            guard let path, !path.isEmpty else { continue }
            let isDirectory = (item["XADIsDirectory"] as? Bool)
                ?? path.hasSuffix("/")
            let size = (item["XADFileSize"] as? NSNumber)?.int64Value
            entries.append(
                ParsedEntry(
                    path: path,
                    isDirectory: isDirectory,
                    size: size
                )
            )
        }
        return entries
    }

    static func parseSevenZipSLT(_ output: String) -> [ParsedEntry] {
        var entries: [ParsedEntry] = []
        var currentPath: String?
        var currentSize: Int64?
        var currentIsDirectory = false

        func flush() {
            guard let path = currentPath, !path.isEmpty else { return }
            entries.append(
                ParsedEntry(
                    path: path,
                    isDirectory: currentIsDirectory,
                    size: currentSize
                )
            )
            currentPath = nil
            currentSize = nil
            currentIsDirectory = false
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flush()
                continue
            }
            if line.hasPrefix("Path = ") {
                flush()
                currentPath = String(line.dropFirst("Path = ".count))
            } else if line.hasPrefix("Size = ") {
                currentSize = Int64(line.dropFirst("Size = ".count))
            } else if line.hasPrefix("Attributes = ") {
                currentIsDirectory = String(line.dropFirst("Attributes = ".count)).contains("D")
            }
        }
        flush()
        return entries
    }
}
