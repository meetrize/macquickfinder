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

    func execute(
        _ snippet: Snippet,
        context: SnippetExecutionContext,
        inSystemTerminal: Bool? = nil
    ) {
        let useSystemTerminal = inSystemTerminal ?? snippet.useSystemTerminal
        if settings.confirmDestructiveSnippets, isDestructive(snippet.content) {
            pendingDestructiveSnippet = snippet
            pendingContext = context
            pendingUseSystemTerminal = useSystemTerminal
            return
        }
        performExecute(snippet, context: context, useSystemTerminal: useSystemTerminal)
    }

    /// 从 AppKit 右键菜单执行；危险命令用 NSAlert 确认，不依赖 Snippets 面板是否可见。
    func executeFromMenu(
        _ snippet: Snippet,
        context: SnippetExecutionContext,
        inSystemTerminal: Bool? = nil
    ) {
        let useSystemTerminal = inSystemTerminal ?? snippet.useSystemTerminal
        if settings.confirmDestructiveSnippets, isDestructive(snippet.content) {
            let alert = NSAlert()
            alert.messageText = "危险命令确认"
            alert.informativeText = "此 Snippet 可能删除或移动文件，确定执行？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "取消")
            alert.addButton(withTitle: "仍要执行")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        performExecute(snippet, context: context, useSystemTerminal: useSystemTerminal)
    }

    func confirmDestructiveExecution() {
        guard let snippet = pendingDestructiveSnippet, let context = pendingContext else { return }
        let useSystemTerminal = pendingUseSystemTerminal
        pendingDestructiveSnippet = nil
        pendingContext = nil
        pendingUseSystemTerminal = false
        performExecute(snippet, context: context, useSystemTerminal: useSystemTerminal)
    }

    func cancelDestructiveExecution() {
        pendingDestructiveSnippet = nil
        pendingContext = nil
        pendingUseSystemTerminal = false
    }

    private var pendingContext: SnippetExecutionContext?
    private var pendingUseSystemTerminal = false

    private func performExecute(
        _ snippet: Snippet,
        context: SnippetExecutionContext,
        useSystemTerminal: Bool
    ) {
        let expanded: String
        do {
            expanded = try SnippetExpander.expand(
                snippet.content,
                context: context,
                scriptType: snippet.scriptType
            )
        } catch {
            reportExpansionError(error, snippet: snippet)
            return
        }

        let cwd = resolveWorkingDirectory(snippet: snippet, context: context)

        if useSystemTerminal {
            do {
                try SystemTerminalRunner.run(
                    snippet: snippet,
                    expandedContent: expanded,
                    workingDirectory: cwd
                )
                store.recordExecution(id: snippet.id)
            } catch {
                reportExpansionError(error, snippet: snippet, expandedContent: expanded)
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

        let jobID = jobStore.createJob(
            snippetName: snippet.name,
            displayCommand: displayCommand,
            source: .snippet(id: snippet.id, name: snippet.name),
            expandedContent: expanded,
            workingDirectory: cwd
        )

        if settings.autoShowOutputPanelOnShellRun {
            if let layout = ActiveWindowLayoutCenter.shared.keyWindowLayout {
                ActiveWindowLayoutCenter.shared.showOutputPanel(on: layout)
            }
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

    private func reportExpansionError(
        _ error: Error,
        snippet: Snippet,
        expandedContent: String? = nil
    ) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        expansionErrorMessage = message
        let jobID = jobStore.createJob(
            snippetName: snippet.name,
            displayCommand: snippet.content,
            source: .snippet(id: snippet.id, name: snippet.name),
            expandedContent: expandedContent ?? snippet.content
        )
        jobStore.markFailed(jobID: jobID, message: message + "\n")
        if settings.autoShowOutputPanelOnShellRun {
            if let layout = ActiveWindowLayoutCenter.shared.keyWindowLayout {
                ActiveWindowLayoutCenter.shared.showOutputPanel(on: layout)
            }
        }
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
