import AppKit
import Foundation

enum ArchiveTaskRunner {
    private static let sizeThresholdBytes: Int64 = 32 * 1024 * 1024

    @MainActor
    static func run(
        displayCommand: String,
        shellCommand: String,
        workingDirectory: String?,
        jobTitle: String,
        estimatedBytes: Int64,
        volumePaths: [String],
        containsDirectory: Bool,
        onComplete: @escaping (Result<Void, Error>) -> Void
    ) {
        let useOutputPanel = shouldUseOutputPanel(
            estimatedBytes: estimatedBytes,
            volumePaths: volumePaths,
            containsDirectory: containsDirectory
        )

        if useOutputPanel {
            let networkHint = volumePaths.contains { DirectorySizeVolumeFilter.isNetworkVolume(path: $0) }
            JobStore.shared.runArchiveShellCommand(
                jobTitle: jobTitle,
                displayCommand: displayCommand,
                shellCommand: shellCommand,
                workingDirectory: workingDirectory,
                preamble: networkHint ? L10n.Archive.hintNetworkSlow + "\n" : nil
            ) { status in
                switch status {
                case .succeeded:
                    onComplete(.success(()))
                case .cancelled:
                    onComplete(.failure(ArchiveOperationsError.cancelled))
                default:
                    onComplete(.failure(ArchiveOperationsError.commandFailed(exitCode: 1)))
                }
            }
        } else {
            NotificationCenter.default.post(
                name: .explorerTransientNotice,
                object: nil,
                userInfo: ["message": displayCommand]
            )
            Task {
                do {
                    try await runSilent(shellCommand: shellCommand, workingDirectory: workingDirectory)
                    await MainActor.run {
                        onComplete(.success(()))
                    }
                } catch {
                    await MainActor.run {
                        onComplete(.failure(error))
                        presentError(error)
                    }
                }
            }
        }
    }

    static func shouldUseOutputPanel(
        estimatedBytes: Int64,
        volumePaths: [String],
        containsDirectory: Bool
    ) -> Bool {
        if volumePaths.contains(where: { DirectorySizeVolumeFilter.isNetworkVolume(path: $0) }) {
            return true
        }
        if containsDirectory {
            return true
        }
        return estimatedBytes >= sizeThresholdBytes
    }

    private static func runSilent(shellCommand: String, workingDirectory: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", shellCommand]
            if let workingDirectory, !workingDirectory.isEmpty {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(throwing: ArchiveOperationsError.shellOutput(output))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    @MainActor
    private static func presentError(_ error: Error) {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            NSAlert(messageText: description).runModal()
            return
        }
        NSAlert(error: error).runModal()
    }
}

private extension NSAlert {
    convenience init(messageText: String) {
        self.init()
        self.messageText = messageText
        self.alertStyle = .warning
        addButton(withTitle: L10n.Action.ok)
    }
}
