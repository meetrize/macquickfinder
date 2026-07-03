import Foundation
import FileList

/// 从预览顶栏运行 Shell / Python / AppleScript 文件，输出写入底部输出面板。
@MainActor
enum PreviewScriptRunner {
    static func run(file: FileItem) {
        let ext = file.url.pathExtension.lowercased()
        guard let scriptType = PreviewTypeClassifier.runnableScriptType(forExtension: ext) else { return }

        let cwd = file.url.deletingLastPathComponent().path
        let displayCommand = displayCommand(for: file, scriptType: scriptType)

        let jobID = JobStore.shared.createJob(
            snippetName: file.name,
            displayCommand: displayCommand,
            source: .previewScript(path: file.url.path),
            expandedContent: displayCommand,
            workingDirectory: cwd
        )

        NotificationCenter.default.post(
            name: .outputPanelCommandExecuted,
            object: nil,
            userInfo: ["jobID": jobID, "command": displayCommand]
        )

        if let layout = ActiveWindowLayoutCenter.shared.resolveLayoutForOutputPanel() {
            ActiveWindowLayoutCenter.shared.showOutputPanel(on: layout)
        }

        JobStore.shared.appendOutput(
            jobID: jobID,
            stdout: OutputSessionFormatting.prompt(cwd: cwd, command: displayCommand)
        )

        let process = Process()
        process.environment = ProcessInfo.processInfo.environment
        if !cwd.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        switch scriptType {
        case .shell:
            process.executableURL = URL(fileURLWithPath: shellInterpreter(for: file))
            process.arguments = [file.url.path]
        case .python3:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [file.url.path]
        case .appleScript:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [file.url.path]
        }

        ProcessOutputStreamer.attach(to: process, jobID: jobID)
        do {
            try process.run()
            JobStore.shared.markRunning(jobID: jobID, process: process)
        } catch {
            JobStore.shared.markFailed(jobID: jobID, message: error.localizedDescription)
        }
    }

    private static func shellInterpreter(for file: FileItem) -> String {
        switch file.url.pathExtension.lowercased() {
        case "bash":
            return SnippetDefaults.bashInterpreter
        case "zsh":
            return SnippetDefaults.shellInterpreter
        default:
            return SnippetDefaults.shellInterpreter
        }
    }

    private static func displayCommand(for file: FileItem, scriptType: SnippetScriptType) -> String {
        let path = ShellQuoting.singleQuote(file.url.path)
        switch scriptType {
        case .shell:
            return "\(shellInterpreter(for: file)) \(path)"
        case .python3:
            return "python3 \(path)"
        case .appleScript:
            return "osascript \(path)"
        }
    }
}
