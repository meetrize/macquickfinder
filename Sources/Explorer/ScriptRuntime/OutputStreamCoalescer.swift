import Foundation

/// 将子进程 stdout/stderr 小块合并后再刷新到 `JobStore`，避免高频输出淹没主线程。
actor OutputStreamCoalescer {
    static let shared = OutputStreamCoalescer()

    private struct Pending {
        var stdout = ""
        var stderr = ""
    }

    private var pending: [UUID: Pending] = [:]
    private var scheduledFlush: Set<UUID> = []

    /// 合并刷新间隔（运行中命令约 4 次/秒刷新 UI，避免主线程过载）。
    private let flushIntervalNanoseconds: UInt64 = 250_000_000

    func enqueue(jobID: UUID, stdout: String? = nil, stderr: String? = nil) {
        var entry = pending[jobID] ?? Pending()
        if let stdout, !stdout.isEmpty {
            entry.stdout += stdout
        }
        if let stderr, !stderr.isEmpty {
            entry.stderr += stderr
        }
        pending[jobID] = entry
        scheduleFlush(jobID: jobID)
    }

    /// 进程结束时立即刷出剩余缓冲。
    func flushNow(jobID: UUID) async {
        scheduledFlush.remove(jobID)
        while true {
            guard let entry = pending.removeValue(forKey: jobID) else { break }
            let stdoutChunk = entry.stdout
            let stderrChunk = entry.stderr
            guard !stdoutChunk.isEmpty || !stderrChunk.isEmpty else { continue }
            await MainActor.run {
                JobStore.shared.appendOutput(
                    jobID: jobID,
                    stdout: stdoutChunk.isEmpty ? nil : stdoutChunk,
                    stderr: stderrChunk.isEmpty ? nil : stderrChunk
                )
            }
        }
    }

    private func scheduleFlush(jobID: UUID) {
        guard !scheduledFlush.contains(jobID) else { return }
        scheduledFlush.insert(jobID)
        let id = jobID
        Task {
            try? await Task.sleep(nanoseconds: self.flushIntervalNanoseconds)
            await self.flush(jobID: id)
        }
    }

    private func flush(jobID: UUID) async {
        scheduledFlush.remove(jobID)

        guard let entry = pending.removeValue(forKey: jobID) else { return }

        let stdoutChunk = entry.stdout
        let stderrChunk = entry.stderr

        if !stdoutChunk.isEmpty || !stderrChunk.isEmpty {
            await MainActor.run {
                JobStore.shared.appendOutput(
                    jobID: jobID,
                    stdout: stdoutChunk.isEmpty ? nil : stdoutChunk,
                    stderr: stderrChunk.isEmpty ? nil : stderrChunk
                )
            }
        }

        if let remaining = pending[jobID],
           !remaining.stdout.isEmpty || !remaining.stderr.isEmpty {
            scheduleFlush(jobID: jobID)
        }
    }
}
