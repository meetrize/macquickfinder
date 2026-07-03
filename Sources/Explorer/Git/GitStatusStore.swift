import Combine
import Foundation

@MainActor
final class GitStatusStore: ObservableObject {
    static let shared = GitStatusStore()

    @Published private(set) var snapshot: GitWorkspaceSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var trackedCWD: String?

    private var refreshTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var pendingCWD: String?
    private var refreshGeneration = 0
    private let debounceNanoseconds: UInt64 = 500_000_000
    private let cli: GitCLI

    init(cli: GitCLI = .live) {
        self.cli = cli
    }

    func scheduleRefresh(cwd: String) {
        pendingCWD = cwd
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceNanoseconds ?? 500_000_000)
            guard !Task.isCancelled else { return }
            guard let self, let pendingCWD = self.pendingCWD else { return }
            await self.refresh(cwd: pendingCWD)
        }
    }

    func cancelScheduledRefresh() {
        debounceTask?.cancel()
        debounceTask = nil
        pendingCWD = nil
    }

    func refresh(cwd: String) async {
        await performRefresh(cwd: cwd, retryIfStillDirty: false)
    }

    /// Git 写操作完成后刷新：取消排队中的 debounce，并在仍显示脏状态时重试一次。
    func refreshAfterGitOperation(cwd: String) async {
        cancelScheduledRefresh()
        await performRefresh(cwd: cwd, retryIfStillDirty: true)
    }

    func clearPendingChanges(forRepoRoot repoRoot: String) {
        guard let snapshot, GitRepositoryDetector.rootsEqual(snapshot.repoRoot, repoRoot) else { return }
        self.snapshot = snapshot.clearingEntries()
    }

    private func performRefresh(cwd: String, retryIfStillDirty: Bool) async {
        pendingCWD = cwd
        refreshTask?.cancel()
        refreshGeneration += 1
        let generation = refreshGeneration

        let cli = cli
        trackedCWD = cwd
        isRefreshing = true
        lastError = nil

        if let currentRoot = snapshot?.repoRoot,
           let newRoot = GitRepositoryDetector.findRepoRoot(from: cwd),
           !GitRepositoryDetector.rootsEqual(currentRoot, newRoot) {
            snapshot = nil
        }

        let task = Task {
            let loaded: Result<GitWorkspaceSnapshot?, Error>
            do {
                let snapshot = try await Task.detached(priority: .utility) {
                    try GitWorkspaceReader.loadSnapshot(cwd: cwd, cli: cli)
                }.value
                loaded = .success(snapshot)
            } catch {
                loaded = .failure(error)
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.applyRefreshResult(loaded, generation: generation)
            }
        }
        refreshTask = task
        await task.value

        guard retryIfStillDirty,
              let snapshot,
              !snapshot.entries.isEmpty,
              let repoRoot = GitRepositoryDetector.findRepoRoot(from: cwd),
              GitRepositoryDetector.rootsEqual(snapshot.repoRoot, repoRoot) else {
            return
        }

        try? await Task.sleep(nanoseconds: 200_000_000)
        await performRefresh(cwd: cwd, retryIfStillDirty: false)
    }

    private func applyRefreshResult(_ loaded: Result<GitWorkspaceSnapshot?, Error>, generation: Int) {
        guard generation == refreshGeneration else { return }
        switch loaded {
        case .success(let snapshot):
            self.snapshot = snapshot
            self.lastError = nil
        case .failure(let error):
            self.lastError = error.localizedDescription
        }
        isRefreshing = false
    }

    func clear() {
        debounceTask?.cancel()
        debounceTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        refreshGeneration += 1
        snapshot = nil
        lastError = nil
        isRefreshing = false
        trackedCWD = nil
        pendingCWD = nil
    }
}

extension GitCLIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Git executable not found"
        case .timedOut(let seconds):
            return "Git command timed out after \(Int(seconds)) seconds"
        case .nonZeroExit(let code, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "Git exited with status \(code)"
            }
            return detail
        case .invalidUTF8Output:
            return "Git produced invalid UTF-8 output"
        }
    }
}
