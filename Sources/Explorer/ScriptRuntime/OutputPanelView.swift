import SwiftUI
import AppKit
import FileList

private enum OutputPanelFocusField: Hashable {
    case command
    case find
}

struct OutputPanelView: View {
    @ObservedObject var layout: ExplorerWindowLayoutState
    var maxPanelHeight: CGFloat = 800
    let executionContext: OutputExecutionContext
    var onNavigateToDirectory: (String) -> Void = { _ in }
    @ObservedObject private var jobStore = JobStore.shared
    @State private var findText = ""
    @State private var commandDraft = ""
    @State private var commandHistories: [UUID: OutputCommandHistory] = [:]
    @State private var completionSessions: [UUID: OutputCommandCompletionSession] = [:]
    @State private var previousDirectories: [UUID: String] = [:]
    @State private var completionListHint: String?
    @State private var isHistoryPopoverPresented = false
    @State private var isOutputAreaActive = false
    /// 拖拽过程中的临时高度，避免每帧写 UserDefaults 导致抖动
    @State private var dragPanelHeight: CGFloat?
    @FocusState private var focusedField: OutputPanelFocusField?

    private var effectivePanelHeight: CGFloat {
        if layout.isOutputPanelContentCollapsed {
            return OutputPanelMetrics.titleBarHeight
        }
        return dragPanelHeight ?? CGFloat(layout.outputPanelHeight)
    }

    private var isOutputContextActive: Bool {
        isOutputAreaActive || focusedField != nil
    }

    var body: some View {
        if layout.isOutputPanelVisible {
            VStack(spacing: 0) {
                if layout.isOutputPanelContentCollapsed {
                    Divider()
                } else {
                    OutputPanelResizeHandle(
                        panelHeight: dragPanelHeight ?? CGFloat(layout.outputPanelHeight),
                        minHeight: 80,
                        maxHeight: maxPanelHeight,
                        onHeightChange: { dragPanelHeight = $0 },
                        onDragEnded: { finalHeight in
                            layout.outputPanelHeight = Double(finalHeight)
                            dragPanelHeight = nil
                        }
                    )
                    .frame(height: 14)
                }

                panelContent
                    .frame(height: effectivePanelHeight)
            }
            .animation(nil, value: effectivePanelHeight)
            .onChange(of: layout.isOutputPanelVisible) { visible in
                if !visible {
                    focusedField = nil
                    OutputPanelTextEditingCenter.shared.setActive(false)
                }
            }
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            jobTabBar
            if !layout.isOutputPanelContentCollapsed {
                if let job = jobStore.selectedJob {
                    VStack(spacing: 0) {
                        outputArea(job: job)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        bottomBar(job: job)
                    }
                    .onAppear { syncCommandDraft(for: job) }
                    .onChange(of: jobStore.selectedJobID) { _ in
                        if let job = jobStore.selectedJob {
                            syncCommandDraft(for: job)
                            resetHistoryBrowsing(for: job.id)
                        }
                    }
                } else {
                    Text(L10n.Snippets.Output.emptyHint)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(OutputPanelKeyMonitor(
            isFindActive: isOutputContextActive,
            isInterruptEnabled: jobStore.selectedJob?.status == .running,
            onFind: { focusedField = .find },
            onInterrupt: {
                guard let job = jobStore.selectedJob, job.status == .running else { return }
                jobStore.cancel(jobID: job.id)
            }
        ))
    }

    private var jobTabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(jobStore.jobs) { job in
                        HStack(spacing: 4) {
                            Button {
                                jobStore.selectedJobID = job.id
                            } label: {
                                Text(job.snippetName)
                                    .lineLimit(1)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(jobStore.selectedJobID == job.id ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(4)

                            Button {
                                jobStore.removeJob(id: job.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.trailing, 4)
                        .contextMenu {
                            Button(L10n.Snippets.Output.closeCurrent) {
                                jobStore.removeJob(id: job.id)
                            }

                            Button(L10n.Snippets.Output.closeOthers) {
                                jobStore.removeOtherJobs(keeping: job.id)
                            }

                            Button(L10n.Snippets.Output.closeAll) {
                                jobStore.removeAllJobs()
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Button {
                layout.isOutputPanelContentCollapsed.toggle()
            } label: {
                Image(systemName: layout.isOutputPanelContentCollapsed ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
            .instantHoverTooltip(layout.isOutputPanelContentCollapsed ? L10n.Snippets.Output.expand : L10n.Snippets.Output.collapse)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

            Button {
                jobStore.closeOutputPanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .instantHoverTooltip(L10n.Snippets.Output.closePanel)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func outputArea(job: JobRecord) -> some View {
        VStack(spacing: 0) {
            if job.status == .failed {
                failureBanner(job: job)
            }
            outputText(job: job)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isOutputAreaActive = true
            focusedField = nil
        }
    }

    private func bottomBar(job: JobRecord) -> some View {
        VStack(spacing: 0) {
            Divider()
            if let completionListHint {
                Text(completionListHint)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(OutputPanelStyle.commandTextColor.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .lineLimit(3)
            }
            HStack(alignment: .center, spacing: 10) {
                commandTextField(for: job)

                trailingControls(job: job)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .focusedValue(\.textFieldEditing, focusedField != nil)
        .background(TextEditingKeyMonitor(isActive: focusedField != nil))
    }

    private func trailingControls(job: JobRecord) -> some View {
        HStack(spacing: 8) {
            commandHistoryButton(job: job)

            findTextField
        }
        .font(.caption)
    }

    private func commandTextField(for job: JobRecord) -> some View {
        OutputCommandField(
            text: $commandDraft,
            isEnabled: true,
            onFocusChange: { focused in
                if focused {
                    focusedField = .command
                    isOutputAreaActive = false
                } else if focusedField == .command {
                    focusedField = nil
                }
            },
            onSubmit: {
                rerunCommand(for: job)
            },
            onHistoryNavigate: { direction in
                navigateCommandHistory(for: job.id, direction: direction)
            },
            onTabComplete: { line, cursor in
                completeCommand(for: job.id, line: line, cursor: cursor)
            },
            onCompletionSessionReset: {
                resetCompletionSession(for: job.id)
            }
        )
        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
        .modifier(OutputCommandCapsuleFieldStyle(isFocused: focusedField == .command))
    }

    private func commandHistoryButton(job: JobRecord) -> some View {
        Button {
            isHistoryPopoverPresented.toggle()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(commandHistories[job.id]?.entries.isEmpty ?? true)
        .popover(isPresented: $isHistoryPopoverPresented, arrowEdge: .top) {
            commandHistoryPopoverContent(jobID: job.id)
        }
    }

    private func commandHistoryPopoverContent(jobID: UUID) -> some View {
        let entries = (commandHistories[jobID]?.entries ?? []).reversed()
        return VStack(alignment: .leading, spacing: 8) {
            if entries.isEmpty {
                Text("No history")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, command in
                            commandHistoryRow(
                                jobID: jobID,
                                command: command,
                                displayIndex: index + 1
                            )
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(8)
        .frame(width: 400, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func commandHistoryRow(jobID: UUID, command: String, displayIndex: Int) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(String(format: "%2d", displayIndex))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(OutputPanelStyle.historyRunButtonIcon)
                    .frame(width: 30, alignment: .center)
                    .frame(maxHeight: .infinity)
                    .background(OutputPanelStyle.historyRunButtonFill.opacity(0.85))
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(OutputPanelStyle.historyRunButtonBorder.opacity(0.35))
                            .frame(width: 1)
                    }

                Text(command)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(OutputPanelStyle.commandTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                    .padding(.vertical, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                commandDraft = command
                resetHistoryBrowsing(for: jobID)
                focusedField = .command
                isHistoryPopoverPresented = false
            }

            ZStack {
                Color.clear
                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(OutputPanelStyle.historyRunButtonIcon)
            }
            .frame(width: 28)
            .frame(maxHeight: .infinity)
            .background(OutputPanelStyle.historyRunButtonFill)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(OutputPanelStyle.historyRunButtonBorder.opacity(0.35))
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                executeHistoryCommand(jobID: jobID, command: command)
            }
            .help(L10n.Snippets.Output.runHistoryCommand)
        }
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(OutputPanelStyle.commandBackgroundColor.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(OutputPanelStyle.commandBorderColor.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func executeHistoryCommand(jobID: UUID, command: String) {
        guard let job = jobStore.jobs.first(where: { $0.id == jobID }) else { return }
        guard job.status != .running else { return }

        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let currentDirectory = executionContext.cwd
        jobStore.executeInPlace(
            jobID: jobID,
            rawCommand: trimmed,
            context: executionContext,
            previousDirectory: previousDirectories[jobID],
            onDirectoryChange: { newDirectory in
                previousDirectories[jobID] = currentDirectory
                onNavigateToDirectory(newDirectory)
            }
        )
        recordCommandHistory(trimmed, for: jobID)
        resetCompletionSession(for: jobID)
        completionListHint = nil
        isHistoryPopoverPresented = false
    }

    private var findTextField: some View {
        TextField(L10n.Snippets.Output.find, text: $findText)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(OutputPanelStyle.commandTextColor)
            .tint(OutputPanelStyle.commandFocusBorderColor)
            .padding(.leading, focusedField == .find ? 2 : 14)
            .frame(width: 128)
            .modifier(OutputCommandCapsuleFieldStyle(isFocused: focusedField == .find))
            .overlay(alignment: .leading) {
                if focusedField != .find {
                    Button {
                        focusedField = .find
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(OutputPanelStyle.commandTextColor.opacity(0.85))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 10)
                    .help(L10n.Snippets.Output.find)
                }
            }
            .focused($focusedField, equals: .find)
            .onChange(of: focusedField) { field in
                if field == .find {
                    OutputPanelTextEditingCenter.shared.setActive(true)
                } else if field != .command {
                    OutputPanelTextEditingCenter.shared.setActive(false)
                }
            }
    }

    private func failureBanner(job: JobRecord) -> some View {
        Text(L10n.Snippets.Output.commandFailed(Int(job.exitCode ?? -1)))
            .font(.caption)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color.red.opacity(0.85))
    }

    private func outputText(job: JobRecord) -> some View {
        OutputPanelOutputScrollView(
            job: job,
            findText: findText
        )
    }

    private func syncCommandDraft(for job: JobRecord) {
        commandDraft = job.expandedContent
    }

    private func rerunCommand(for job: JobRecord) {
        let trimmed = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard job.status != .running else { return }

        let currentDirectory = executionContext.cwd
        jobStore.rerunEditedCommand(
            fromJobID: job.id,
            content: trimmed,
            context: executionContext,
            previousDirectory: previousDirectories[job.id],
            onDirectoryChange: { newDirectory in
                previousDirectories[job.id] = currentDirectory
                onNavigateToDirectory(newDirectory)
            }
        )
        recordCommandHistory(trimmed, for: job.id)
        resetCompletionSession(for: job.id)
        completionListHint = nil
        commandDraft = ""
    }

    private func recordCommandHistory(_ command: String, for jobID: UUID) {
        var history = commandHistories[jobID] ?? OutputCommandHistory()
        history.record(command)
        commandHistories[jobID] = history
    }

    private func resetHistoryBrowsing(for jobID: UUID) {
        guard var history = commandHistories[jobID] else { return }
        history.resetBrowsing()
        commandHistories[jobID] = history
    }

    private func navigateCommandHistory(
        for jobID: UUID,
        direction: OutputCommandHistoryDirection
    ) -> String? {
        var history = commandHistories[jobID] ?? OutputCommandHistory()
        guard let value = history.step(direction, currentDraft: commandDraft) else { return nil }
        commandHistories[jobID] = history
        commandDraft = value
        return value
    }

    private func completeCommand(
        for jobID: UUID,
        line: String,
        cursor: Int
    ) -> OutputCommandCompletionResult? {
        var session = completionSessions[jobID] ?? OutputCommandCompletionSession()
        let request = OutputCommandCompletionRequest(
            line: line,
            cursor: cursor,
            cwd: executionContext.cwd
        )
        let result = OutputCommandCompleter.complete(
            request: request,
            session: &session,
            candidatesProvider: nil
        )
        completionSessions[jobID] = session
        if let list = result?.listForDisplay, !list.isEmpty {
            completionListHint = list.joined(separator: "  ")
        } else if result != nil {
            completionListHint = nil
        }
        if let result {
            commandDraft = result.line
        }
        return result
    }

    private func resetCompletionSession(for jobID: UUID) {
        completionSessions[jobID] = OutputCommandCompletionSession()
        completionListHint = nil
    }
}

private struct OutputPanelOutputScrollView: View {
    let job: JobRecord
    let findText: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            OutputPanelOutputTextView(
                stdout: job.stdout,
                stderr: job.stderr,
                isRunning: job.status == .running,
                findText: findText,
                emptyPlaceholder: L10n.Snippets.Output.noOutput
            )

            if job.stdout.isEmpty, job.stderr.isEmpty {
                Text(L10n.Snippets.Output.noOutput)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(OutputPanelStyle.placeholderColor)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .background(OutputPanelStyle.backgroundColor)
    }
}

private enum OutputCapsuleFieldMetrics {
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 7
    static let borderWidth: CGFloat = 1.5
    static let height: CGFloat = 30
}

private struct OutputCommandCapsuleFieldStyle: ViewModifier {
    var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, OutputCapsuleFieldMetrics.horizontalPadding)
            .padding(.vertical, OutputCapsuleFieldMetrics.verticalPadding)
            .frame(height: OutputCapsuleFieldMetrics.height)
            .background(
                Capsule(style: .continuous)
                    .fill(OutputPanelStyle.commandBackgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isFocused
                            ? OutputPanelStyle.commandFocusBorderColor
                            : OutputPanelStyle.commandBorderColor,
                        lineWidth: OutputCapsuleFieldMetrics.borderWidth
                    )
            )
    }
}

private struct OutputPanelKeyMonitor: NSViewRepresentable {
    let isFindActive: Bool
    let isInterruptEnabled: Bool
    let onFind: () -> Void
    let onInterrupt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFind: onFind, onInterrupt: onInterrupt)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isFindActive = isFindActive
        context.coordinator.isInterruptEnabled = isInterruptEnabled
    }

    final class Coordinator {
        var isFindActive: Bool
        var isInterruptEnabled: Bool
        let onFind: () -> Void
        let onInterrupt: () -> Void
        private var monitor: Any?

        init(onFind: @escaping () -> Void, onInterrupt: @escaping () -> Void) {
            self.onFind = onFind
            self.onInterrupt = onInterrupt
            self.isFindActive = false
            self.isInterruptEnabled = false
        }

        func install(on view: NSView) {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event)
            }
        }

        private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
            switch OutputPanelKeyboard.action(
                for: event,
                isFindActive: isFindActive,
                isInterruptEnabled: isInterruptEnabled
            ) {
            case .interrupt:
                onInterrupt()
                return nil
            case .find:
                onFind()
                return nil
            case nil:
                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
