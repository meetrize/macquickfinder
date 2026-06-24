import Foundation
import AppKit

@MainActor
enum AppleScriptEngine {
    static func run(snippet: Snippet, expandedContent: String, jobID: UUID) {
        if expandedContent.contains("display dialog") || expandedContent.contains("display alert") {
            runInProcess(expandedContent: expandedContent, jobID: jobID)
        } else {
            runViaOSAScript(expandedContent: expandedContent, jobID: jobID)
        }
    }

    private static func runInProcess(expandedContent: String, jobID: UUID) {
        JobStore.shared.markRunning(jobID: jobID, process: Process())
        var errorDict: NSDictionary?
        let script = NSAppleScript(source: expandedContent)
        let descriptor = script?.executeAndReturnError(&errorDict)
        if let errorDict {
            let msg = (errorDict[NSAppleScript.errorMessage] as? String) ?? "AppleScript 错误"
            JobStore.shared.appendOutput(jobID: jobID, stderr: msg)
            JobStore.shared.markFinished(jobID: jobID, exitCode: 1)
            return
        }
        if let str = descriptor?.stringValue, !str.isEmpty {
            JobStore.shared.appendOutput(jobID: jobID, stdout: str + "\n")
        }
        JobStore.shared.markFinished(jobID: jobID, exitCode: 0)
    }

    private static func runViaOSAScript(expandedContent: String, jobID: UUID) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", expandedContent]
        ProcessOutputStreamer.attach(to: process, jobID: jobID)
        do {
            try process.run()
            JobStore.shared.markRunning(jobID: jobID, process: process)
        } catch {
            JobStore.shared.markFailed(jobID: jobID, message: error.localizedDescription)
        }
    }
}
