import SwiftUI
import AppKit
import FileList

private enum OutputPanelFocusField: Hashable {
    case command
    case find
}

struct OutputPanelView: View {
    @ObservedObject var layout: ExplorerWindowLayoutState
    var containerHeight: CGFloat = 800
    var maxPanelHeight: CGFloat = 800
    let executionContext: OutputExecutionContext
    var onNavigateToDirectory: (String) -> Void = { _ in }
    @ObservedObject private var jobStore = JobStore.shared
    @State private var findText = ""
    @State private var findNextToken: UInt = 0
    @State private var findMatchCount = 0
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
    @State private var prefersCommandFieldFocus = false
    @State private var commandRefocusToken: UInt = 0
    @State private var isCommandInputExpanded = false
    @State private var multilineRefocusToken: UInt = 0
    /// 强制展开状态：用户主动点击省略号展开后，即使内容不再需要折叠也保持展开
    @State private var forceCommandExpanded = false

    private var desiredPanelHeight: CGFloat {
        if layout.isOutputPanelContentCollapsed {
            return OutputPanelMetrics.titleBarHeight
        }
        return dragPanelHeight ?? CGFloat(layout.outputPanelHeight)
    }

    private var clampedPanelHeight: CGFloat {
        OutputPanelMetrics.clampedPanelHeight(
            desired: desiredPanelHeight,
            containerHeight: containerHeight,
            isContentCollapsed: layout.isOutputPanelContentCollapsed
        )
    }

    private var isOutputContextActive: Bool {
        isOutputAreaActive || focusedField != nil
    }

    var body: some View {
        if layout.isOutputPanelVisible {
            panelContent
                .frame(height: clampedPanelHeight)
                .overlay(alignment: .top) {
                    if layout.isOutputPanelContentCollapsed {
                        Divider()
                    } else {
                        OutputPanelResizeHandle(
                            panelHeight: desiredPanelHeight,
                            minHeight: OutputPanelMetrics.minimumExpandedChromeHeight,
                            maxHeight: maxPanelHeight,
                            onHeightChange: { dragPanelHeight = $0 },
                            onDragEnded: { finalHeight in
                                layout.outputPanelHeight = Double(finalHeight)
                                dragPanelHeight = nil
                            }
                        )
                        .frame(height: OutputPanelMetrics.resizeHandleHeight)
                        .offset(y: -OutputPanelMetrics.resizeHandleHeight)
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .animation(nil, value: clampedPanelHeight)
            .onAppear {
                setupCommandExecutedObserver()
            }
            .onAppear {
                if layout.isOutputPanelVisible {
                    jobStore.ensureShellSessionIfNeeded()
                }
            }
            .onChange(of: layout.isOutputPanelVisible) { visible in
                if visible {
                    jobStore.ensureShellSessionIfNeeded()
                } else {
                    focusedField = nil
                    OutputPanelTextEditingCenter.shared.setActive(false)
                }
            }
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            if !layout.isOutputPanelContentCollapsed, let job = jobStore.selectedJob {
                VStack(spacing: 0) {
                    jobTabBar
                    outputArea(job: job)
                        .frame(minHeight: 0, maxHeight: .infinity)
                    bottomBar(job: job)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .onAppear { syncCommandDraft(for: job) }
                        .task(id: job.id) {
                            syncCommandDraft(for: job)
                        }
                        .onChange(of: jobStore.selectedJobID) { _ in
                            if let job = jobStore.selectedJob {
                                syncCommandDraft(for: job)
                                resetHistoryBrowsing(for: job.id)
                            }
                        }
                        .onChange(of: job.status) { status in
                            guard prefersCommandFieldFocus else { return }
                            switch status {
                            case .succeeded, .failed, .cancelled:
                                scheduleCommandFieldRefocus()
                            default:
                                break
                            }
                        }
                        .onChange(of: job.expandedContent) { _ in
                            syncCommandDraft(for: job)
                        }
                }
                .frame(minHeight: 0, maxHeight: .infinity)
                .clipped()
            } else {
                jobTabBar
                if !layout.isOutputPanelContentCollapsed {
                    Text(L10n.Snippets.Output.emptyHint)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(OutputPanelKeyMonitor(
            isFindActive: isOutputContextActive,
            isFindFieldFocused: focusedField == .find,
            isCommandFieldFocused: focusedField == .command,
            isInterruptEnabled: jobStore.selectedJob?.status == .running,
            onFind: { focusedField = .find },
            onFindNext: {
                requestFindNextMatch()
            },
            onInterrupt: {
                guard let job = jobStore.selectedJob, job.status == .running else { return }
                jobStore.cancel(jobID: job.id)
            }
        ))
    }

    private var jobTabBar: some View {
        HStack(alignment: .center, spacing: 0) {
            CenteredHorizontalScrollView(height: OutputPanelMetrics.titleBarHeight) {
                HStack(alignment: .center, spacing: 4) {
                    ForEach(jobStore.jobs) { job in
                        jobTabChip(job: job)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: OutputPanelMetrics.titleBarHeight)

            titleBarIconButton(
                systemName: layout.isOutputPanelContentCollapsed ? "chevron.up" : "chevron.down",
                tooltip: layout.isOutputPanelContentCollapsed ? L10n.Snippets.Output.expand : L10n.Snippets.Output.collapse
            ) {
                layout.isOutputPanelContentCollapsed.toggle()
            }

            titleBarIconButton(
                systemName: "xmark",
                tooltip: L10n.Snippets.Output.closePanel
            ) {
                jobStore.closeOutputPanel()
            }
        }
        .frame(height: OutputPanelMetrics.titleBarHeight)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func jobTabChip(job: JobRecord) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Text(job.snippetName)
                .lineLimit(1)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    jobStore.selectedJobID = job.id
                }

            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
                .onTapGesture {
                    jobStore.removeJob(id: job.id)
                }
        }
        .padding(.horizontal, 6)
        .frame(height: OutputPanelMetrics.titleBarChipHeight, alignment: .center)
        .background(jobStore.selectedJobID == job.id ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .padding(.trailing, 4)
        .frame(height: OutputPanelMetrics.titleBarHeight, alignment: .center)
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

    private func titleBarIconButton(
        systemName: String,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .frame(
                width: OutputPanelMetrics.titleBarIconWidth,
                height: OutputPanelMetrics.titleBarHeight,
                alignment: .center
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .instantHoverTooltip(tooltip)
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
            prefersCommandFieldFocus = false
            collapseCommandInput()
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
            HStack(alignment: commandBarAlignment(for: job), spacing: 10) {
                commandBarGroup(for: job)
                findTextField
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .focusedValue(\.textFieldEditing, focusedField != nil)
        .background(TextEditingKeyMonitor(isActive: focusedField != nil))
    }

    private func commandBarAlignment(for job: JobRecord) -> VerticalAlignment {
        isCommandInputExpanded ? .top : .center
    }

    private func effectiveCommand(for job: JobRecord) -> String {
        // 如果有 commandDraft（非空或刚编辑过），优先使用它
        if !commandDraft.isEmpty {
            return commandDraft
        }
        return job.expandedContent
    }

    private func commandNeedsCollapse(for job: JobRecord) -> Bool {
        // 如果用户强制展开，即使内容本身不需要折叠也保持展开状态
        guard !forceCommandExpanded else { return true }
        return OutputCommandPreview.needsCollapse(effectiveCommand(for: job))
    }

    private func collapseCommandInput() {
        guard isCommandInputExpanded else { return }
        isCommandInputExpanded = false
        forceCommandExpanded = false
    }

    private func commandBarGroup(for job: JobRecord) -> some View {
        let expanded = isCommandInputExpanded
        return VStack(alignment: .leading, spacing: 4) {
            // 主输入行
            HStack(alignment: expanded ? .top : .center, spacing: 0) {
                commandInputContent(for: job)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                // 单行/多行切换按钮（仅在需要折叠时显示）
                if commandNeedsCollapse(for: job) {
                    singleLineToggleButton(for: job)
                        .padding(.top, expanded ? 4 : 0)
                }
                commandHistoryButton(job: job)
                    .padding(.top, expanded ? 4 : 0)
            }
            .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

            // 执行按钮（仅在展开多行时显示，靠右对齐）
            if expanded {
                HStack(spacing: 0) {
                    Spacer()
                    runButton(for: job)
                }
            }
        }
        .modifier(OutputCommandInputChromeStyle(isExpanded: expanded))
    }

    /// 执行按钮
    private func runButton(for job: JobRecord) -> some View {
        Button {
            rerunCommand(for: job)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(L10n.Snippets.Output.runCommand)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(L10n.Snippets.Output.runCommand)
    }

    /// 单行/多行切换按钮
    private func singleLineToggleButton(for job: JobRecord) -> some View {
        Button {
            if isCommandInputExpanded {
                collapseCommandInput()
            } else {
                expandToMultiline(for: job)
            }
        } label: {
            Image(systemName: isCommandInputExpanded ? "chevron.down" : "arrow.up.and.down.text.horizontal")
                .font(.system(size: NSFont.systemFontSize, weight: .medium))
                .foregroundStyle(OutputPanelStyle.commandFieldTextColor.opacity(0.85))
                .frame(width: 28, height: 22)
        }
        .buttonStyle(.plain)
        .help(isCommandInputExpanded ? L10n.Snippets.Output.collapseCommand : L10n.Snippets.Output.expandCommand)
    }

    @ViewBuilder
    private func commandInputContent(for job: JobRecord) -> some View {
        if commandNeedsCollapse(for: job) {
            if isCommandInputExpanded {
                expandedCommandInput(for: job)
            } else {
                collapsedCommandInput(for: job)
            }
        } else {
            commandTextField(for: job)
        }
    }

    private func collapsedCommandInput(for job: JobRecord) -> some View {
        let preview = OutputCommandPreview.collapsedLine(effectiveCommand(for: job))
        return HStack(spacing: 0) {
            // 显示预览文本（点击展开为多行）
            Text(preview)
                .font(.system(size: NSFont.systemFontSize, design: .monospaced))
                .foregroundStyle(OutputPanelStyle.commandFieldTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    expandToMultiline(for: job)
                }
        }
    }

    /// 展开为多行编辑器
    private func expandToMultiline(for job: JobRecord) {
        ensureFullCommandDraft(for: job)
        isCommandInputExpanded = true
        forceCommandExpanded = true
        multilineRefocusToken &+= 1
    }

    private func expandedCommandInput(for job: JobRecord) -> some View {
        OutputCommandMultilineField(
            text: $commandDraft,
            isEnabled: true,
            refocusToken: multilineRefocusToken,
            onFocusChange: { focused in
                if focused {
                    focusedField = .command
                    isOutputAreaActive = false
                    prefersCommandFieldFocus = true
                } else if focusedField == .command {
                    focusedField = nil
                    prefersCommandFieldFocus = false
                }
            },
            onSubmit: {
                rerunCommand(for: job)
            }
        )
        .frame(height: OutputCommandPreview.expandedEditorHeight(for: commandDraft), alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commandTextField(for job: JobRecord) -> some View {
        OutputCommandField(
            text: $commandDraft,
            isEnabled: true,
            refocusToken: commandRefocusToken,
            onFocusChange: { focused in
                if focused {
                    focusedField = .command
                    isOutputAreaActive = false
                    prefersCommandFieldFocus = true
                } else if focusedField == .command {
                    focusedField = nil
                    prefersCommandFieldFocus = false
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
            },
            onControlC: { action in
                handleCommandControlC(action, jobID: job.id)
            }
        )
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func commandHistoryButton(job: JobRecord) -> some View {
        let isDisabled = commandHistories[job.id]?.entries.isEmpty ?? true
        return Button {
            isHistoryPopoverPresented.toggle()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: NSFont.systemFontSize, weight: .regular))
                .foregroundStyle(
                    OutputPanelStyle.commandFieldTextColor.opacity(isDisabled ? 0.35 : 1)
                )
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 22)
        .padding(.trailing, 4)
        .disabled(isDisabled)
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
        HStack(spacing: 4) {
            if focusedField != .find {
                Button {
                    collapseCommandInput()
                    focusedField = .find
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: NSFont.systemFontSize, weight: .regular))
                        .foregroundStyle(OutputPanelStyle.commandFieldTextColor.opacity(0.85))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(L10n.Snippets.Output.find)
            }

            OutputFindField(
                text: $findText,
                isFocused: Binding(
                    get: { focusedField == .find },
                    set: { focused in
                        if focused {
                            collapseCommandInput()
                            focusedField = .find
                            isOutputAreaActive = false
                            prefersCommandFieldFocus = false
                        } else if focusedField == .find {
                            focusedField = nil
                        }
                    }
                ),
                onSubmit: {
                    requestFindNextMatch()
                }
            )
            .frame(minWidth: 72, maxWidth: .infinity)

            if !findText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    requestFindNextMatch()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: NSFont.systemFontSize, weight: .regular))
                        .foregroundStyle(OutputPanelStyle.commandFieldTextColor.opacity(0.85))
                        .frame(width: 30, height: 26)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help(L10n.Preview.Toolbar.nextMatch)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 176)
        .modifier(OutputCommandCapsuleFieldStyle())
        .onChange(of: findText) { _ in
            findNextToken = 0
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
            findText: findText,
            findNextToken: findNextToken,
            findMatchCount: $findMatchCount
        )
    }

    private func syncCommandDraft(for job: JobRecord) {
        // 新标签页打开时，命令输入框保持为空
        commandDraft = ""
        isCommandInputExpanded = false
        forceCommandExpanded = false
    }

    /// 设置监听来自 Snippets 面板首次执行的命令通知
    private func setupCommandExecutedObserver() {
        NotificationCenter.default.addObserver(
            forName: .outputPanelCommandExecuted,
            object: nil,
            queue: .main
        ) { [self] notification in
            guard let jobID = notification.userInfo?["jobID"] as? UUID,
                  let command = notification.userInfo?["command"] as? String else { return }
            recordCommandHistory(command, for: jobID)
        }
    }

    /// `commandDraft` 始终保存完整命令；若被折叠预览污染则还原为 job 原文。
    private func ensureFullCommandDraft(for job: JobRecord) {
        let jobFull = job.expandedContent
        guard !jobFull.isEmpty else { return }
        if commandDraft.isEmpty
            || commandDraft == OutputCommandPreview.collapsedLine(jobFull)
            || (jobFull.contains("\n") && !commandDraft.contains("\n")) {
            commandDraft = jobFull
        }
    }

    private func rerunCommand(for job: JobRecord) {
        let trimmed = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard job.status != .running else { return }

        prefersCommandFieldFocus = true
        // 执行后清空命令输入框并收起多行编辑器
        commandDraft = ""
        isCommandInputExpanded = false
        forceCommandExpanded = false

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

    private func scheduleCommandFieldRefocus() {
        commandRefocusToken &+= 1
        focusedField = .command
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard prefersCommandFieldFocus else { return }
            commandRefocusToken &+= 1
            focusedField = .command
        }
    }

    private func handleCommandControlC(_ action: OutputCommandControlCAction, jobID: UUID) {
        switch action {
        case .clearInput:
            commandDraft = ""
            resetCompletionSession(for: jobID)
            completionListHint = nil
        case .closeCurrentJobTab:
            closeCurrentJobTab(jobID: jobID)
        }
    }

    private func closeCurrentJobTab(jobID: UUID) {
        commandHistories.removeValue(forKey: jobID)
        completionSessions.removeValue(forKey: jobID)
        previousDirectories.removeValue(forKey: jobID)
        isHistoryPopoverPresented = false
        prefersCommandFieldFocus = false
        focusedField = nil
        jobStore.removeJob(id: jobID)
    }

    private func requestFindNextMatch() {
        guard !findText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let selectedJobID = jobStore.selectedJobID {
            NotificationCenter.default.post(
                name: .outputPanelFindNextRequested,
                object: nil,
                userInfo: ["jobID": selectedJobID]
            )
        }
        findNextToken &+= 1
    }
}

private struct OutputPanelOutputScrollView: View {
    let job: JobRecord
    let findText: String
    let findNextToken: UInt
    @Binding var findMatchCount: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            OutputPanelOutputTextView(
                jobID: job.id,
                stdout: job.stdout,
                stderr: job.stderr,
                isRunning: job.status == .running,
                findText: findText,
                findNextToken: findNextToken,
                findMatchCount: $findMatchCount,
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
    static let height: CGFloat = 30
}

private struct OutputCommandInputChromeStyle: ViewModifier {
    var isExpanded: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, isExpanded ? 6 : 7)
            .frame(minHeight: isExpanded ? nil : OutputCapsuleFieldMetrics.height)
            .background(
                RoundedRectangle(cornerRadius: isExpanded ? 10 : 18, style: .continuous)
                    .fill(OutputPanelStyle.commandFieldBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isExpanded ? 10 : 18, style: .continuous)
                    .strokeBorder(
                        isExpanded
                            ? OutputPanelStyle.commandFocusBorderColor.opacity(0.5)
                            : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isExpanded ? OutputPanelStyle.commandFocusBorderColor.opacity(0.12) : .clear,
                radius: 8,
                y: 2
            )
    }
}

private struct OutputCommandCapsuleFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, OutputCapsuleFieldMetrics.horizontalPadding)
            .padding(.vertical, OutputCapsuleFieldMetrics.verticalPadding)
            .frame(height: OutputCapsuleFieldMetrics.height)
            .background(
                Capsule(style: .continuous)
                    .fill(OutputPanelStyle.commandFieldBackgroundColor)
            )
    }
}

private struct OutputPanelKeyMonitor: NSViewRepresentable {
    let isFindActive: Bool
    let isFindFieldFocused: Bool
    let isCommandFieldFocused: Bool
    let isInterruptEnabled: Bool
    let onFind: () -> Void
    let onFindNext: () -> Void
    let onInterrupt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFind: onFind, onFindNext: onFindNext, onInterrupt: onInterrupt)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isFindActive = isFindActive
        context.coordinator.isFindFieldFocused = isFindFieldFocused
        context.coordinator.isCommandFieldFocused = isCommandFieldFocused
        context.coordinator.isInterruptEnabled = isInterruptEnabled
    }

    final class Coordinator {
        var isFindActive: Bool
        var isFindFieldFocused: Bool
        var isCommandFieldFocused: Bool
        var isInterruptEnabled: Bool
        let onFind: () -> Void
        let onFindNext: () -> Void
        let onInterrupt: () -> Void
        private var monitor: Any?

        init(onFind: @escaping () -> Void, onFindNext: @escaping () -> Void, onInterrupt: @escaping () -> Void) {
            self.onFind = onFind
            self.onFindNext = onFindNext
            self.onInterrupt = onInterrupt
            self.isFindActive = false
            self.isFindFieldFocused = false
            self.isCommandFieldFocused = false
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
            if isFindFieldFocused, (event.keyCode == 36 || event.keyCode == 76) {
                onFindNext()
                return nil
            }
            switch OutputPanelKeyboard.action(
                for: event,
                isFindActive: isFindActive,
                isCommandFieldFocused: isCommandFieldFocused,
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
