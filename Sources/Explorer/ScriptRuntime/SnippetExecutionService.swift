import Foundation

/// Snippet 执行分发：Job 创建后的 scriptType 路由与编辑后重跑。
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
        jobStore: JobStore? = nil,
        settings: SnippetsSettings? = nil
    ) {
        let jobStore = jobStore ?? JobStore.shared
        let settings = settings ?? SnippetsSettings.shared
        guard let job = jobStore.jobs.first(where: { $0.id == fromJobID }) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard case .snippet(let snippetID, let name) = job.source,
              let snippet = SnippetStore.shared.snippet(id: snippetID) else { return }

        let displayCommand = SnippetDisplayCommand.build(snippet: snippet, expandedContent: trimmed)
        let newJobID = jobStore.createJob(
            snippetName: name,
            displayCommand: displayCommand,
            source: job.source,
            expandedContent: trimmed,
            workingDirectory: job.workingDirectory
        )

        if settings.autoShowOutputPanelOnShellRun {
            OutputPanelPresenter.showIfAutoEnabled()
        }

        dispatch(
            snippet: snippet,
            expandedContent: trimmed,
            jobID: newJobID,
            workingDirectory: job.workingDirectory,
            jobStore: jobStore
        )
    }
}
