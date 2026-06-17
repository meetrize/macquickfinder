import Foundation

@MainActor
enum ShellRunner {
    static func run(
        snippet: Snippet,
        expandedContent: String,
        jobID: UUID,
        workingDirectory: String?
    ) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        switch snippet.scriptType {
        case .shell:
            let interpreter = snippet.interpreter ?? SnippetDefaults.shellInterpreter
            process.executableURL = URL(fileURLWithPath: interpreter)
            process.arguments = ["-lc", expandedContent]
        case .python3:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            if expandedContent.contains("\n") {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("snippet-\(jobID.uuidString).py")
                try? expandedContent.write(to: tempURL, atomically: true, encoding: .utf8)
                process.arguments = [tempURL.path]
            } else {
                process.arguments = ["-c", expandedContent]
            }
        case .appleScript:
            return
        }

        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                JobStore.shared.appendOutput(jobID: jobID, stdout: text)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                JobStore.shared.appendOutput(jobID: jobID, stderr: text)
            }
        }

        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                JobStore.shared.markFinished(jobID: jobID, exitCode: proc.terminationStatus)
            }
        }

        do {
            try process.run()
            JobStore.shared.markRunning(jobID: jobID, process: process)
        } catch {
            JobStore.shared.markFailed(jobID: jobID, message: error.localizedDescription)
        }
    }
}
