import Foundation

/// Snippet 执行分发：Job 创建后的 scriptType 路由与输出面板原地续跑。
@MainActor
enum SnippetExecutionService {
    static func dispatch(
        snippet: Snippet,
        expandedContent: String,
        jobID: UUID,
        workingDirectory: String?,
        jobStore: JobStore? = nil
    ) {
        let jobStore = jobStore ?? JobStore.shared
        switch snippet.scriptType {
        case .shell, .python3:
            jobStore.scheduleShellRun(
                snippet: snippet,
                expandedContent: expandedContent,
                jobID: jobID,
                workingDirectory: workingDirectory
            )
        case .appleScript:
            AppleScriptEngine.run(
                snippet: snippet,
                expandedContent: expandedContent,
                jobID: jobID
            )
        }
    }

    static func rerunEditedCommand(
        fromJobID: UUID,
        content: String,
        context: OutputExecutionContext,
        jobStore: JobStore? = nil,
        settings: SnippetsSettings? = nil,
        previousDirectory: String? = nil,
        onDirectoryChange: ((String) -> Void)? = nil
    ) {
        let jobStore = jobStore ?? JobStore.shared
        jobStore.executeInPlace(
            jobID: fromJobID,
            rawCommand: content,
            context: context,
            settings: settings,
            previousDirectory: previousDirectory,
            onDirectoryChange: onDirectoryChange
        )
    }

    static func resolveShellSnippet(for job: JobRecord) -> Snippet {
        if case .snippet(let snippetID, _) = job.source,
           let snippet = SnippetStore.shared.snippet(id: snippetID),
           snippet.scriptType == .shell {
            return snippet
        }
        return SnippetDefaults.inPlaceShellSnippet
    }
}
