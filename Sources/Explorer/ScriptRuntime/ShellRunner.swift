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

        ProcessOutputStreamer.attach(to: process, jobID: jobID)

        do {
            try process.run()
            JobStore.shared.markRunning(jobID: jobID, process: process)
        } catch {
            JobStore.shared.markFailed(jobID: jobID, message: error.localizedDescription)
        }
    }
}
