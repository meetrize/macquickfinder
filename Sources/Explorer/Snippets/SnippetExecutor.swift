import Foundation
import AppKit

@MainActor
final class SnippetExecutor: ObservableObject {
    static let shared = SnippetExecutor()

    @Published var pendingDestructiveSnippet: Snippet?
    @Published var expansionErrorMessage: String?

    private let store = SnippetStore.shared
    private let jobStore = JobStore.shared
    private let settings = SnippetsSettings.shared

    private init() {}

    func execute(_ snippet: Snippet, context: SnippetExecutionContext) {
        if settings.confirmDestructiveSnippets, isDestructive(snippet.content) {
            pendingDestructiveSnippet = snippet
            pendingContext = context
            return
        }
        performExecute(snippet, context: context)
    }

    func confirmDestructiveExecution() {
        guard let snippet = pendingDestructiveSnippet, let context = pendingContext else { return }
        pendingDestructiveSnippet = nil
        pendingContext = nil
        performExecute(snippet, context: context)
    }

    func cancelDestructiveExecution() {
        pendingDestructiveSnippet = nil
        pendingContext = nil
    }

    private var pendingContext: SnippetExecutionContext?

    private func performExecute(_ snippet: Snippet, context: SnippetExecutionContext) {
        let expanded: String
        do {
            expanded = try SnippetExpander.expand(
                snippet.content,
                context: context,
                scriptType: snippet.scriptType
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            expansionErrorMessage = message
            let jobID = jobStore.createJob(
                snippetName: snippet.name,
                displayCommand: snippet.content,
                source: .snippet(id: snippet.id, name: snippet.name),
                expandedContent: snippet.content
            )
            jobStore.markFailed(jobID: jobID, message: message + "\n")
            if settings.autoShowOutputPanelOnShellRun {
                settings.isOutputPanelVisible = true
                settings.isOutputPanelContentCollapsed = false
            }
            return
        }

        let displayCommand: String
        switch snippet.scriptType {
        case .shell:
            let interpreter = snippet.interpreter ?? SnippetDefaults.shellInterpreter
            displayCommand = "\(interpreter) -lc '\(expanded)'"
        case .python3:
            displayCommand = "python3 << '\(expanded.prefix(80))…'"
        case .appleScript:
            displayCommand = expanded
        }

        let cwd = resolveWorkingDirectory(snippet: snippet, context: context)

        let jobID = jobStore.createJob(
            snippetName: snippet.name,
            displayCommand: displayCommand,
            source: .snippet(id: snippet.id, name: snippet.name),
            expandedContent: expanded,
            workingDirectory: cwd
        )

        if settings.autoShowOutputPanelOnShellRun {
            settings.isOutputPanelVisible = true
            settings.isOutputPanelContentCollapsed = false
        }

        switch snippet.scriptType {
        case .shell, .python3:
            jobStore.scheduleShellRun(
                snippet: snippet,
                expandedContent: expanded,
                jobID: jobID,
                workingDirectory: cwd
            )
        case .appleScript:
            AppleScriptEngine.run(snippet: snippet, expandedContent: expanded, jobID: jobID)
        }

        store.recordExecution(id: snippet.id)
    }

    private func resolveWorkingDirectory(snippet: Snippet, context: SnippetExecutionContext) -> String? {
        switch snippet.workingDirectory {
        case .cwd, nil:
            return context.cwd
        case .selectedParent:
            return context.selectedItems.first.map { ($0.url.deletingLastPathComponent().path) }
        case .fixedPath(let path):
            return path
        }
    }

    private func isDestructive(_ content: String) -> Bool {
        let lowered = content.lowercased()
        let patterns = ["rm -rf", "rm -r", "rm ", "mv ", "mkfs", "dd if="]
        return patterns.contains { lowered.contains($0) }
    }
}
