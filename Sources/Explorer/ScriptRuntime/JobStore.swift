import Foundation
import Combine

@MainActor
final class JobStore: ObservableObject {
    static let shared = JobStore()

    @Published private(set) var jobs: [JobRecord] = []
    @Published var selectedJobID: UUID?

    private var settings: SnippetsSettings { SnippetsSettings.shared }
    private let maxStoredJobs = 50
    private var pendingShellRuns: [PendingShellRun] = []
    private var pendingOutputPublishes: [UUID: JobRecord] = [:]
    private var outputPublishScheduled = false

    private struct PendingShellRun {
        var jobID: UUID
        var snippet: Snippet
        var expandedContent: String
        var workingDirectory: String?
    }

    private init() {}

    var selectedJob: JobRecord? {
        guard let id = selectedJobID else { return jobs.last }
        return jobs.first { $0.id == id } ?? jobs.last
    }

    @discardableResult
    func createJob(
        snippetName: String,
        displayCommand: String,
        source: JobSource,
        expandedContent: String? = nil,
        workingDirectory: String? = nil
    ) -> UUID {
        let job = JobRecord(
            id: UUID(),
            snippetName: snippetName,
            displayCommand: displayCommand,
            expandedContent: expandedContent ?? displayCommand,
            workingDirectory: workingDirectory,
            source: source,
            status: .queued,
            stdout: "",
            stderr: "",
            outputTruncated: false,
            exitCode: nil,
            startedAt: nil,
            endedAt: nil,
            process: nil
        )
        jobs.append(job)
        selectedJobID = job.id
        trimOldJobs()
        return job.id
    }

    func appendOutput(jobID: UUID, stdout: String? = nil, stderr: String? = nil) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        var job = pendingOutputPublishes[jobID] ?? jobs[idx]
        let wasTruncated = job.outputTruncated

        if let stdout, !stdout.isEmpty {
            _ = OutputStreamLimiter.append(
                stdout: &job.stdout,
                stderr: &job.stderr,
                truncated: &job.outputTruncated,
                stdoutChunk: stdout,
                stderrChunk: nil,
                truncationNotice: L10n.Snippets.Output.truncated
            )
        }
        if let stderr, !stderr.isEmpty {
            _ = OutputStreamLimiter.append(
                stdout: &job.stdout,
                stderr: &job.stderr,
                truncated: &job.outputTruncated,
                stdoutChunk: OutputSessionFormatting.wrapStderr(stderr),
                stderrChunk: nil,
                truncationNotice: L10n.Snippets.Output.truncated
            )
        }

        if job.status == .running {
            OutputRunningDisplayBuffer.trimPreservingTail(&job.stdout)
            pendingOutputPublishes[jobID] = job
            if job.outputTruncated, !wasTruncated {
                publishOutputNow(jobID: jobID, job: job)
                pendingOutputPublishes.removeValue(forKey: jobID)
            } else {
                scheduleRunningOutputPublish()
            }
        } else {
            publishOutputNow(jobID: jobID, job: job)
        }

        if !wasTruncated, job.outputTruncated {
            terminateProcess(for: jobID)
        }
    }

    private func publishOutputNow(jobID: UUID, job: JobRecord) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[idx].stdout = job.stdout
        jobs[idx].stderr = job.stderr
        jobs[idx].outputTruncated = job.outputTruncated
    }

    private func scheduleRunningOutputPublish() {
        guard !outputPublishScheduled else { return }
        outputPublishScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            self.outputPublishScheduled = false
            self.flushPendingOutputPublishes()
        }
    }

    private func flushPendingOutputPublishes() {
        let pending = pendingOutputPublishes
        pendingOutputPublishes.removeAll()
        for (jobID, job) in pending {
            publishOutputNow(jobID: jobID, job: job)
        }
    }

    private func flushPendingOutput(for jobID: UUID) {
        guard let job = pendingOutputPublishes.removeValue(forKey: jobID) else { return }
        publishOutputNow(jobID: jobID, job: job)
    }

    func markRunning(jobID: UUID, process: Process) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[idx].status = .running
        jobs[idx].process = process
        jobs[idx].startedAt = Date()
    }

    func markFinished(jobID: UUID, exitCode: Int32) {
        flushPendingOutput(for: jobID)
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        if jobs[idx].status == .cancelled {
            return
        }
        jobs[idx].exitCode = exitCode
        jobs[idx].endedAt = Date()
        jobs[idx].process = nil
        jobs[idx].status = exitCode == 0 ? .succeeded : .failed
        appendOutput(jobID: jobID, stdout: OutputSessionFormatting.completionStatus(exitCode: exitCode))
        pumpQueue()
    }

    func markFailed(jobID: UUID, message: String) {
        flushPendingOutput(for: jobID)
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        appendOutput(jobID: jobID, stderr: message)
        appendOutput(jobID: jobID, stdout: OutputSessionFormatting.completionStatus(exitCode: 1))
        jobs[idx].endedAt = Date()
        jobs[idx].process = nil
        jobs[idx].status = .failed
        jobs[idx].exitCode = 1
        pumpQueue()
    }

    func cancel(jobID: UUID) {
        pendingShellRuns.removeAll { $0.jobID == jobID }
        flushPendingOutput(for: jobID)
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        if jobs[idx].status == .running {
            if let process = jobs[idx].process, process.isRunning {
                process.terminate()
            }
        }
        jobs[idx].process = nil
        jobs[idx].status = .cancelled
        jobs[idx].endedAt = Date()
        appendOutput(jobID: jobID, stdout: OutputSessionFormatting.cancelledStatus())
        pumpQueue()
    }

    func removeJob(id: UUID) {
        cancel(jobID: id)
        jobs.removeAll { $0.id == id }
        if selectedJobID == id {
            selectedJobID = jobs.last?.id
        }
        if jobs.isEmpty {
            closeOutputPanel(clearJobs: false)
        }
    }

    /// 关闭除指定 Job 外的所有 Job。
    func removeOtherJobs(keeping keptJobID: UUID) {
        let idsToRemove = jobs.map(\.id).filter { $0 != keptJobID }
        guard !idsToRemove.isEmpty else { return }
        for id in idsToRemove {
            cancel(jobID: id)
        }
        jobs.removeAll { $0.id != keptJobID }
        selectedJobID = keptJobID
    }

    /// 关闭全部 Job（不隐藏输出面板）。
    func removeAllJobs() {
        pendingShellRuns.removeAll()
        for job in jobs where job.status == .running {
            if let process = job.process, process.isRunning {
                process.terminate()
            }
        }
        jobs.removeAll()
        selectedJobID = nil
        closeOutputPanel(clearJobs: false)
    }

    /// 关闭输出面板；可选是否清空 Job 列表（总关闭按钮会取消运行中任务并清空）。
    func closeOutputPanel(clearJobs: Bool = true) {
        pendingShellRuns.removeAll()
        if clearJobs {
            for job in jobs where job.status == .running {
                if let process = job.process, process.isRunning {
                    process.terminate()
                }
            }
            jobs.removeAll()
            selectedJobID = nil
        }
        if let layout = ActiveWindowLayoutCenter.shared.keyWindowLayout {
            ActiveWindowLayoutCenter.shared.hideOutputPanel(on: layout)
        } else {
            ActiveWindowLayoutCenter.shared.hideOutputPanelOnAllWindows()
        }
    }

    func clearOutput(jobID: UUID) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[idx].stdout = ""
        jobs[idx].stderr = ""
        jobs[idx].outputTruncated = false
    }

    func rerunEditedCommand(
        fromJobID: UUID,
        content: String,
        context: OutputExecutionContext,
        previousDirectory: String? = nil,
        onDirectoryChange: ((String) -> Void)? = nil
    ) {
        SnippetExecutionService.rerunEditedCommand(
            fromJobID: fromJobID,
            content: content,
            context: context,
            jobStore: self,
            previousDirectory: previousDirectory,
            onDirectoryChange: onDirectoryChange
        )
    }

    func executeInPlace(
        jobID: UUID,
        rawCommand: String,
        context: OutputExecutionContext,
        settings: SnippetsSettings? = nil,
        previousDirectory: String? = nil,
        onDirectoryChange: ((String) -> Void)? = nil
    ) {
        let settings = settings ?? SnippetsSettings.shared
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }

        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let status = jobs[index].status
        guard status != .running else { return }

        if trimmed == "clear" {
            applyClearCommand(jobID: jobID, index: index, cwd: SnippetExpander.standardize(context.cwd))
            return
        }

        inlinePendingStderr(jobID: jobID)

        let snippet = SnippetExecutionService.resolveShellSnippet(for: jobs[index])
        let cwd = SnippetExpander.standardize(context.cwd)

        do {
            let expanded = try SnippetExpander.expand(
                trimmed,
                context: context.snippetContext,
                scriptType: .shell
            )

            if let onDirectoryChange,
               let newDirectory = OutputDirectoryChangeParser.resolveLeadingDirectoryChange(
                expandedCommand: expanded,
                currentDirectory: cwd,
                previousDirectory: previousDirectory
               ) {
                onDirectoryChange(newDirectory)
            }

            appendOutput(
                jobID: jobID,
                stdout: OutputSessionFormatting.prompt(cwd: cwd, command: trimmed)
            )

            jobs[index].expandedContent = trimmed
            jobs[index].displayCommand = trimmed
            jobs[index].workingDirectory = cwd
            jobs[index].status = .queued
            jobs[index].exitCode = nil
            jobs[index].endedAt = nil
            jobs[index].startedAt = nil
            jobs[index].process = nil

            if settings.autoShowOutputPanelOnShellRun {
                OutputPanelPresenter.showIfAutoEnabled()
            }

            scheduleShellRun(
                snippet: snippet,
                expandedContent: expanded,
                jobID: jobID,
                workingDirectory: cwd
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            appendOutput(
                jobID: jobID,
                stdout: OutputSessionFormatting.prompt(cwd: cwd, command: trimmed)
            )
            appendOutput(jobID: jobID, stderr: message + "\n")
            appendOutput(jobID: jobID, stdout: OutputSessionFormatting.completionStatus(exitCode: 1))
            jobs[index].expandedContent = trimmed
            jobs[index].displayCommand = trimmed
            jobs[index].workingDirectory = cwd
            jobs[index].status = .failed
            jobs[index].exitCode = 1
            jobs[index].endedAt = Date()
            jobs[index].process = nil
        }
    }

    func runningCount() -> Int {
        jobs.filter { $0.status == .running }.count
    }

    func scheduleShellRun(
        snippet: Snippet,
        expandedContent: String,
        jobID: UUID,
        workingDirectory: String?
    ) {
        let pending = PendingShellRun(
            jobID: jobID,
            snippet: snippet,
            expandedContent: expandedContent,
            workingDirectory: workingDirectory
        )
        if runningCount() < settings.clampedMaxConcurrentJobs {
            startShellRun(pending)
        } else {
            pendingShellRuns.append(pending)
        }
    }

    private func startShellRun(_ pending: PendingShellRun) {
        ShellRunner.run(
            snippet: pending.snippet,
            expandedContent: pending.expandedContent,
            jobID: pending.jobID,
            workingDirectory: pending.workingDirectory
        )
    }

    private func pumpQueue() {
        while runningCount() < settings.clampedMaxConcurrentJobs, !pendingShellRuns.isEmpty {
            let next = pendingShellRuns.removeFirst()
            startShellRun(next)
        }
    }

    private func trimOldJobs() {
        if jobs.count > maxStoredJobs {
            jobs.removeFirst(jobs.count - maxStoredJobs)
        }
    }

    private func terminateProcess(for jobID: UUID) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }),
              let process = jobs[idx].process,
              process.isRunning else { return }
        process.terminate()
    }

    /// 将旧版独立 stderr 缓冲并入 stdout 时间线（避免错误信息堆在后续命令下方）。
    private func inlinePendingStderr(jobID: UUID) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        let pending = jobs[idx].stderr
        guard !pending.isEmpty else { return }
        jobs[idx].stderr = ""
        appendOutput(jobID: jobID, stdout: OutputSessionFormatting.wrapStderr(pending))
    }

    /// 内置 `clear`：清空当前 Tab 输出，不启动 shell 进程。
    private func applyClearCommand(jobID: UUID, index: Int, cwd: String) {
        clearOutput(jobID: jobID)
        jobs[index].expandedContent = "clear"
        jobs[index].displayCommand = "clear"
        jobs[index].workingDirectory = cwd
        jobs[index].status = .succeeded
        jobs[index].exitCode = 0
        jobs[index].endedAt = Date()
        jobs[index].startedAt = nil
        jobs[index].process = nil
    }
}
