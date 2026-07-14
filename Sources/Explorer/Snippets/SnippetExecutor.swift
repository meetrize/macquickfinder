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
        inSystemTerminal: Bool? = nil,
        layout: ExplorerWindowLayoutState? = nil
    ) {
        let useSystemTerminal = inSystemTerminal ?? snippet.useSystemTerminal
        if settings.confirmDestructiveSnippets, isDestructive(snippet.content) {
            pendingDestructiveSnippet = snippet
            pendingContext = context
            pendingUseSystemTerminal = useSystemTerminal
            pendingLayout = layout
            return
        }
        performExecute(snippet, context: context, useSystemTerminal: useSystemTerminal, layout: layout)
    }

    /// 从 AppKit 右键菜单执行；危险命令用 NSAlert 确认，不依赖 Snippets 面板是否可见。
    func executeFromMenu(
        _ snippet: Snippet,
        context: SnippetExecutionContext,
        inSystemTerminal: Bool? = nil,
        layout: ExplorerWindowLayoutState? = nil
    ) {
        let useSystemTerminal = inSystemTerminal ?? snippet.useSystemTerminal
        if settings.confirmDestructiveSnippets, isDestructive(snippet.content) {
            guard DestructiveActionConfirmer.confirmDestructiveSnippet() else { return }
        }
        performExecute(snippet, context: context, useSystemTerminal: useSystemTerminal, layout: layout)
    }

    func confirmDestructiveExecution() {
        guard let snippet = pendingDestructiveSnippet, let context = pendingContext else { return }
        let useSystemTerminal = pendingUseSystemTerminal
        let layout = pendingLayout
        pendingDestructiveSnippet = nil
        pendingContext = nil
        pendingUseSystemTerminal = false
        pendingLayout = nil
        performExecute(snippet, context: context, useSystemTerminal: useSystemTerminal, layout: layout)
    }

    func cancelDestructiveExecution() {
        pendingDestructiveSnippet = nil
        pendingContext = nil
        pendingUseSystemTerminal = false
        pendingLayout = nil
    }

    private var pendingContext: SnippetExecutionContext?
    private var pendingUseSystemTerminal = false
    private var pendingLayout: ExplorerWindowLayoutState?

    private func performExecute(
        _ snippet: Snippet,
        context: SnippetExecutionContext,
        useSystemTerminal: Bool,
        layout: ExplorerWindowLayoutState? = nil
    ) {
        let askParameters: [SnippetAskParameter]
        do {
            askParameters = try SnippetAskParser.uniqueParameters(in: snippet.content)
        } catch {
            reportExpansionError(error, snippet: snippet, layout: layout)
            return
        }

        let askValues: [String: String]
        if askParameters.isEmpty {
            askValues = [:]
        } else {
            guard let collected = SnippetAskInputPanel.collect(
                parameters: askParameters,
                snippetName: snippet.name
            ) else {
                return
            }
            askValues = collected
        }

        let expanded: String
        do {
            expanded = try SnippetExpander.expand(
                snippet.content,
                context: context,
                scriptType: snippet.scriptType,
                askValues: askValues
            )
        } catch {
            reportExpansionError(error, snippet: snippet, layout: layout)
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
                reportExpansionError(error, snippet: snippet, expandedContent: expanded, layout: layout)
            }
            return
        }

        let displayCommand = SnippetDisplayCommand.build(snippet: snippet, expandedContent: expanded)

        let jobID = jobStore.createJob(
            snippetName: snippet.name,
            displayCommand: displayCommand,
            source: .snippet(id: snippet.id, name: snippet.name),
            expandedContent: expanded,
            workingDirectory: cwd
        )

        // 通知输出面板记录命令到历史
        NotificationCenter.default.post(
            name: .outputPanelCommandExecuted,
            object: nil,
            userInfo: ["jobID": jobID, "command": expanded]
        )

        if settings.autoShowOutputPanelOnShellRun {
            OutputPanelPresenter.showIfAutoEnabled(on: layout)
        }

        SnippetExecutionService.dispatch(
            snippet: snippet,
            expandedContent: expanded,
            jobID: jobID,
            workingDirectory: cwd,
            jobStore: jobStore
        )

        store.recordExecution(id: snippet.id)
    }

    private func reportExpansionError(
        _ error: Error,
        snippet: Snippet,
        expandedContent: String? = nil,
        layout: ExplorerWindowLayoutState? = nil
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
            OutputPanelPresenter.showIfAutoEnabled(on: layout)
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
        SnippetShellSecurityChecker.isDestructive(content)
    }
}
