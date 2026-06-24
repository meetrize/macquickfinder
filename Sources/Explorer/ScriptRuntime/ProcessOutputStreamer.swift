import Foundation

@MainActor
enum ProcessOutputStreamer {
    static func attach(to process: Process, jobID: UUID) {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task {
                await OutputStreamCoalescer.shared.enqueue(jobID: jobID, stdout: text)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task {
                await OutputStreamCoalescer.shared.enqueue(jobID: jobID, stderr: text)
            }
        }
        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            Task {
                await OutputStreamCoalescer.shared.flushNow(jobID: jobID)
                await MainActor.run {
                    JobStore.shared.markFinished(jobID: jobID, exitCode: proc.terminationStatus)
                }
            }
        }
    }
}
