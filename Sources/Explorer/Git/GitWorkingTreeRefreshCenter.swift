import Foundation

extension Notification.Name {
    static let gitWorkingTreeMayHaveChanged = Notification.Name("GitWorkingTreeMayHaveChanged")
}

enum GitWorkingTreeRefreshCenter {
    static let pathUserInfoKey = "path"

    static func notifyWorkingTreeMayHaveChanged(at path: String) {
        guard GitRepositoryDetector.findRepoRoot(from: path) != nil else { return }
        NotificationCenter.default.post(
            name: .gitWorkingTreeMayHaveChanged,
            object: nil,
            userInfo: [pathUserInfoKey: path]
        )
    }

    static func notifyIfShellJobMutatedWorkingTree(job: JobRecord, status: JobStatus) {
        guard status == .succeeded else { return }
        if case .gitOperation = job.source { return }

        let cwd = job.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cwd.isEmpty else { return }

        let candidates = [job.displayCommand, job.expandedContent]
        guard candidates.contains(where: { GitCommandDetector.mutatesWorkingTree($0) }) else { return }

        notifyWorkingTreeMayHaveChanged(at: cwd)
    }
}
