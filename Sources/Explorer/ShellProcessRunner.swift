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
}
