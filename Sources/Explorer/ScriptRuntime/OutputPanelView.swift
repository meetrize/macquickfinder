import SwiftUI
import AppKit

private enum OutputPanelFocusField: Hashable {
    case command
    case find
}

struct OutputPanelView: View {
    var maxPanelHeight: CGFloat = 800

    @ObservedObject private var jobStore = JobStore.shared
    @ObservedObject private var settings = SnippetsSettings.shared
    @State private var findText = ""
    @State private var commandDraft = ""
    @State private var isOutputAreaActive = false
    /// 拖拽过程中的临时高度，避免每帧写 UserDefaults 导致抖动
    @State private var dragPanelHeight: CGFloat?
    @FocusState private var focusedField: OutputPanelFocusField?

    private var effectivePanelHeight: CGFloat {
        dragPanelHeight ?? CGFloat(settings.outputPanelHeight)
    }

    private var isOutputContextActive: Bool {
        isOutputAreaActive || focusedField != nil
    }

    var body: some View {
        if settings.isOutputPanelVisible {
            VStack(spacing: 0) {
                OutputPanelResizeHandle(
                    panelHeight: effectivePanelHeight,
                    minHeight: 80,
                    maxHeight: maxPanelHeight,
                    onHeightChange: { dragPanelHeight = $0 },
                    onDragEnded: { finalHeight in
                        settings.outputPanelHeight = Double(finalHeight)
                        dragPanelHeight = nil
                    }
                )
                .frame(height: 14)

                panelContent
                    .frame(height: effectivePanelHeight)
            }
            .animation(nil, value: effectivePanelHeight)
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            jobTabBar
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
                    }
                }
            } else {
                Text("执行 Snippet 后在此查看输出")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(OutputPanelKeyMonitor(isActive: isOutputContextActive) {
            focusedField = .find
        })
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
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Button {
                jobStore.closeOutputPanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("关闭输出面板")
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
            HStack(alignment: .center, spacing: 10) {
                commandTextField(for: job)

                trailingControls(job: job)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func trailingControls(job: JobRecord) -> some View {
        HStack(spacing: 8) {
            if let duration = job.duration {
                Text(String(format: "%.1fs", duration))
                    .foregroundStyle(.secondary)
            } else if job.status == .running || job.status == .queued {
                Text(job.status == .queued ? "排队中" : "运行中…")
                    .foregroundStyle(.secondary)
            }

            if let code = job.exitCode {
                Text("退出码 \(code)")
                    .foregroundStyle(code == 0 ? Color.secondary : Color.red)
            } else if job.status == .cancelled {
                Text("已取消")
                    .foregroundStyle(.secondary)
            }

            Button("清屏") { jobStore.clearOutput(jobID: job.id) }
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button("复制") { copyAllOutput(job: job) }
                .buttonStyle(.bordered)
                .controlSize(.small)

            findTextField

            if job.status == .running {
                Button("停止") { jobStore.cancel(jobID: job.id) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .font(.caption)
    }

    private func commandTextField(for job: JobRecord) -> some View {
        TextField("展开后的命令，回车重新执行", text: $commandDraft)
            .font(.system(.caption, design: .monospaced))
            .lineLimit(1)
            .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
            .modifier(OutputCapsuleFieldStyle())
            .focused($focusedField, equals: .command)
            .onSubmit { rerunCommand(for: job) }
    }

    private var findTextField: some View {
        TextField("查找", text: $findText)
            .font(.caption)
            .frame(width: 128)
            .modifier(OutputCapsuleFieldStyle())
            .focused($focusedField, equals: .find)
    }

    private func failureBanner(job: JobRecord) -> some View {
        Text("命令失败，退出码 \(job.exitCode ?? -1)")
            .font(.caption)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color.red.opacity(0.85))
    }

    private func outputText(job: JobRecord) -> some View {
        ScrollView {
            Text(highlightedOutput(job: job))
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .textSelection(.enabled)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func highlightedOutput(job: JobRecord) -> AttributedString {
        var combined = job.stdout
        if !job.stderr.isEmpty {
            if !combined.isEmpty { combined += "\n" }
            combined += job.stderr
        }
        var attr = AttributedString(combined.isEmpty ? "（无输出）" : combined)
        if !findText.isEmpty, let range = attr.range(of: findText, options: .caseInsensitive) {
            attr[range].backgroundColor = .yellow.opacity(0.4)
        }
        return attr
    }

    private func copyAllOutput(job: JobRecord) {
        let text = job.stdout + job.stderr
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func syncCommandDraft(for job: JobRecord) {
        commandDraft = job.expandedContent
    }

    private func rerunCommand(for job: JobRecord) {
        let trimmed = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        jobStore.rerunEditedCommand(fromJobID: job.id, content: trimmed)
    }
}

private enum OutputCapsuleFieldMetrics {
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 7
    static let borderWidth: CGFloat = 1.5
    static let height: CGFloat = 30
}

private struct OutputCapsuleFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, OutputCapsuleFieldMetrics.horizontalPadding)
            .padding(.vertical, OutputCapsuleFieldMetrics.verticalPadding)
            .frame(height: OutputCapsuleFieldMetrics.height)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: OutputCapsuleFieldMetrics.borderWidth)
            )
    }
}

private struct OutputPanelKeyMonitor: NSViewRepresentable {
    let isActive: Bool
    let onFind: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFind: onFind)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isActive = isActive
    }

    final class Coordinator {
        var isActive: Bool
        let onFind: () -> Void
        private var monitor: Any?

        init(onFind: @escaping () -> Void) {
            self.onFind = onFind
            self.isActive = false
        }

        func install(on view: NSView) {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event)
            }
        }

        private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
            guard isActive else { return event }
            guard event.modifierFlags.contains(.command) else { return event }
            guard event.charactersIgnoringModifiers?.lowercased() == "f" else { return event }
            onFind()
            return nil
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
