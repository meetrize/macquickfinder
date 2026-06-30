import Foundation

/// 带超时与取消的 shell 命令执行（`sh -c`），供 Archive 预览等场景复用。
enum ShellProcessRunner {
    enum RunnerError: LocalizedError {
        case timedOut

        var errorDescription: String? {
            switch self {
            case .timedOut: return L10n.Error.Shell.timedOut
            }
        }
    }

    static func runCommand(
        _ command: String,
        timeoutSeconds: Int,
        localeEnvironment: [String: String] = ["LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in localeEnvironment {
            environment[key] = value
        }
        process.environment = environment

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
                throw RunnerError.timedOut
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// 按行流式读取命令输出；`head` 关闭管道后子进程会提前结束。
    static func streamCommandLines(
        _ command: String,
        timeoutSeconds: Int,
        localeEnvironment: [String: String] = ["LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await consumeCommandLines(
                        command,
                        timeoutSeconds: timeoutSeconds,
                        localeEnvironment: localeEnvironment
                    ) { line in
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private static func consumeCommandLines(
        _ command: String,
        timeoutSeconds: Int,
        localeEnvironment: [String: String],
        onLine: (String) -> Void
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in localeEnvironment {
            environment[key] = value
        }
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()

        let handle = pipe.fileHandleForReading
        var pending = ""
        let start = Date()

        defer {
            if process.isRunning {
                process.terminate()
            }
        }

        while process.isRunning || handle.availableData.count > 0 {
            if Task.isCancelled {
                throw CancellationError()
            }
            if Date().timeIntervalSince(start) > Double(timeoutSeconds) {
                throw RunnerError.timedOut
            }

            let data = handle.availableData
            if data.isEmpty {
                if process.isRunning {
                    try await Task.sleep(nanoseconds: 15_000_000)
                }
                continue
            }

            guard let chunk = String(data: data, encoding: .utf8) else { continue }
            pending.append(chunk)
            while let newlineIndex = pending.firstIndex(of: "\n") {
                let line = String(pending[..<newlineIndex])
                pending.removeSubrange(...newlineIndex)
                onLine(line)
            }
        }

        if !pending.isEmpty {
            onLine(pending)
        }
        process.waitUntilExit()
    }
}
