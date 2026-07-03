import Foundation

enum GitServiceError: Error, Equatable {
    case cancelled
    case commandFailed(String)
    case emptyCommitMessage
}

@MainActor
enum GitJobRunner {
    static func run(
        title: String,
        arguments: [String],
        workingDirectory: String,
        layout: ExplorerWindowLayoutState?,
        showOutputPanel: Bool = true
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let displayCommand = (["git"] + arguments).joined(separator: " ")
            _ = JobStore.shared.runGitCommand(
                jobTitle: title,
                displayCommand: displayCommand,
                arguments: arguments,
                workingDirectory: workingDirectory,
                showOutputPanel: showOutputPanel,
                layout: layout
            ) { status, job in
                switch status {
                case .succeeded:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: GitServiceError.cancelled)
                case .failed, .queued, .running:
                    let message = Self.failureMessage(from: job)
                    continuation.resume(throwing: GitServiceError.commandFailed(message))
                }
            }
        }
    }

    private static func failureMessage(from job: JobRecord?) -> String {
        guard let job else { return "Git command failed" }
        let combined = [job.stderr, job.stdout]
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Git command failed" : combined
    }
}
