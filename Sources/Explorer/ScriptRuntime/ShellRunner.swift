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
        process.environment = ProcessInfo.processInfo.environment

        switch snippet.scriptType {
        case .shell:
            let interpreter = snippet.interpreter ?? SnippetDefaults.shellInterpreter
            let command = wrapShellCommand(expandedContent, workingDirectory: workingDirectory)
            process.executableURL = URL(fileURLWithPath: interpreter)
            process.arguments = ["-ilc", command]
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

    private static func wrapShellCommand(_ expandedContent: String, workingDirectory: String?) -> String {
        guard let workingDirectory, !workingDirectory.isEmpty else {
            return expandedContent
        }
        let directory = SnippetExpander.standardize(workingDirectory)
        let changeDirectory = "cd \(ShellQuoting.singleQuote(directory))"
        guard !expandedContent.isEmpty else { return changeDirectory }
        return "\(changeDirectory) && \(expandedContent)"
    }
}
