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
        if let stdout { jobs[idx].stdout += stdout }
        if let stderr { jobs[idx].stderr += stderr }
    }

    func markRunning(jobID: UUID, process: Process) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[idx].status = .running
        jobs[idx].process = process
        jobs[idx].startedAt = Date()
    }

    func markFinished(jobID: UUID, exitCode: Int32) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[idx].exitCode = exitCode
        jobs[idx].endedAt = Date()
        jobs[idx].process = nil
        jobs[idx].status = exitCode == 0 ? .succeeded : .failed
        pumpQueue()
    }

    func markFailed(jobID: UUID, message: String) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[idx].stderr += message
        jobs[idx].endedAt = Date()
        jobs[idx].process = nil
        jobs[idx].status = .failed
        jobs[idx].exitCode = 1
        pumpQueue()
    }

    func cancel(jobID: UUID) {
        pendingShellRuns.removeAll { $0.jobID == jobID }
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        if jobs[idx].status == .running {
            jobs[idx].process?.terminate()
        }
        jobs[idx].process = nil
        jobs[idx].status = .cancelled
        jobs[idx].endedAt = Date()
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

    /// 关闭输出面板；可选是否清空 Job 列表（总关闭按钮会取消运行中任务并清空）。
    func closeOutputPanel(clearJobs: Bool = true) {
        pendingShellRuns.removeAll()
        if clearJobs {
            for job in jobs where job.status == .running {
                job.process?.terminate()
            }
            jobs.removeAll()
            selectedJobID = nil
        }
        settings.isOutputPanelVisible = false
    }

    func clearOutput(jobID: UUID) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[idx].stdout = ""
        jobs[idx].stderr = ""
    }

    /// 以编辑后的命令内容重新执行，产生新 Job。
    func rerunEditedCommand(fromJobID: UUID, content: String) {
        guard let job = jobs.first(where: { $0.id == fromJobID }) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard case .snippet(let snippetID, let name) = job.source,
              let snippet = SnippetStore.shared.snippet(id: snippetID) else { return }

        let displayCommand: String
        switch snippet.scriptType {
        case .shell:
            let interpreter = snippet.interpreter ?? SnippetDefaults.shellInterpreter
            displayCommand = "\(interpreter) -lc '\(trimmed)'"
        case .python3:
            displayCommand = trimmed.contains("\n")
                ? "python3 << '\(trimmed.prefix(80))…'"
                : "python3 -c '\(trimmed)'"
        case .appleScript:
            displayCommand = trimmed
        }

        let newJobID = createJob(
            snippetName: name,
            displayCommand: displayCommand,
            source: job.source,
            expandedContent: trimmed,
            workingDirectory: job.workingDirectory
        )

        if settings.autoShowOutputPanelOnShellRun {
            settings.isOutputPanelVisible = true
        }

        switch snippet.scriptType {
        case .shell, .python3:
            scheduleShellRun(
                snippet: snippet,
                expandedContent: trimmed,
                jobID: newJobID,
                workingDirectory: job.workingDirectory
            )
        case .appleScript:
            AppleScriptEngine.run(snippet: snippet, expandedContent: trimmed, jobID: newJobID)
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
}
