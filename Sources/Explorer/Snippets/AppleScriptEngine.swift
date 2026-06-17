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
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
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
