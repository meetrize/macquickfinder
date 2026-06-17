import SwiftUI
import AppKit

struct OutputPanelView: View {
    var maxPanelHeight: CGFloat = 800

    @ObservedObject private var jobStore = JobStore.shared
    @ObservedObject private var settings = SnippetsSettings.shared
    @State private var findText = ""
    /// 拖拽过程中的临时高度，避免每帧写 UserDefaults 导致抖动
    @State private var dragPanelHeight: CGFloat?

    private var effectivePanelHeight: CGFloat {
        dragPanelHeight ?? CGFloat(settings.outputPanelHeight)
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
                metadataBar(job: job)
                if job.status == .failed {
                    failureBanner(job: job)
                }
                outputToolbar(job: job)
                outputText(job: job)
            } else {
                Text("执行 Snippet 后在此查看输出")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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

    private func metadataBar(job: JobRecord) -> some View {
        HStack {
            Text(job.displayCommand)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let code = job.exitCode {
                Text("退出码: \(code)")
                    .font(.caption)
                    .foregroundStyle(code == 0 ? Color.secondary : Color.red)
            }
            if let duration = job.duration {
                Text(String(format: "%.1fs", duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func failureBanner(job: JobRecord) -> some View {
        Text("命令失败，退出码 \(job.exitCode ?? -1)")
            .font(.caption)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color.red.opacity(0.85))
    }

    private func outputToolbar(job: JobRecord) -> some View {
        HStack {
            Button("清屏") { jobStore.clearOutput(jobID: job.id) }
            Button("复制") {
                let text = job.stdout + job.stderr
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            TextField("查找", text: $findText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
            Spacer()
            if job.status == .running {
                Button("停止") { jobStore.cancel(jobID: job.id) }
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
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
}
