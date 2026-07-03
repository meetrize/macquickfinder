import Foundation

enum GitCLIError: Error, Equatable {
    case executableNotFound
    case timedOut(seconds: TimeInterval)
    case nonZeroExit(code: Int32, stderr: String)
    case invalidUTF8Output
}

struct GitCLI: Sendable {
    var executableURL: URL
    var timeout: TimeInterval
    var runProcess: @Sendable (_ executableURL: URL, _ arguments: [String], _ workingDirectory: String, _ timeout: TimeInterval) throws -> GitProcessResult

    init(
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/git"),
        timeout: TimeInterval = 60,
        runProcess: @escaping @Sendable (URL, [String], String, TimeInterval) throws -> GitProcessResult = GitCLI.defaultRunProcess
    ) {
        self.executableURL = executableURL
        self.timeout = timeout
        self.runProcess = runProcess
    }

    static let live = GitCLI(executableURL: GitCLI.resolveExecutableURL())

    static func resolveExecutableURL() -> URL {
        let candidates = [
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
            "/usr/bin/git",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: "/usr/bin/git")
    }

    func run(_ arguments: [String], workingDirectory: String) throws -> String {
        let result = try runData(arguments, workingDirectory: workingDirectory)
        guard let text = String(data: result.stdout, encoding: .utf8) else {
            throw GitCLIError.invalidUTF8Output
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func runData(_ arguments: [String], workingDirectory: String) throws -> GitProcessResult {
        try runProcess(executableURL, arguments, workingDirectory, timeout)
    }
}

struct GitProcessResult: Equatable, Sendable {
    let stdout: Data
    let stderr: Data
    let terminationStatus: Int32
}

extension GitCLI {
    static func defaultRunProcess(
        executableURL: URL,
        arguments: [String],
        workingDirectory: String,
        timeout: TimeInterval
    ) throws -> GitProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw GitCLIError.executableNotFound
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let group = DispatchGroup()
        group.enter()
        var timedOut = false
        let watchdog = DispatchWorkItem {
            timedOut = true
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)

        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            watchdog.cancel()
            group.leave()
        }
        group.wait()

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let status = process.terminationStatus

        if timedOut {
            throw GitCLIError.timedOut(seconds: timeout)
        }
        guard status == 0 else {
            let errText = String(data: stderr, encoding: .utf8) ?? ""
            throw GitCLIError.nonZeroExit(code: status, stderr: errText)
        }
        return GitProcessResult(stdout: stdout, stderr: stderr, terminationStatus: status)
    }
}
