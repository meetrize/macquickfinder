import Foundation

@MainActor
final class GitWorkspaceFSEventsMonitor {
    static let shared = GitWorkspaceFSEventsMonitor()

    private var watcher: DirectoryFSEventsWatcher?
    private var watchedRepoRoot: String?
    private var refreshWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 1.0

    private init() {}

    func updateSession(repoRoot: String?) {
        guard let repoRoot, !repoRoot.isEmpty else {
            stop()
            return
        }

        let normalizedRoot = GitRepositoryDetector.normalizedRepoRoot(repoRoot)
        if let watchedRepoRoot,
           GitRepositoryDetector.rootsEqual(watchedRepoRoot, normalizedRoot) {
            return
        }

        stop()
        watchedRepoRoot = normalizedRoot

        watcher = DirectoryFSEventsWatcher { [weak self] events in
            Task { @MainActor in
                self?.handleEventPaths(events.map(\.path))
            }
        }
        watcher?.start(path: normalizedRoot)
    }

    func stop() {
        refreshWorkItem?.cancel()
        refreshWorkItem = nil
        watcher?.stop()
        watcher = nil
        watchedRepoRoot = nil
    }

    private func handleEventPaths(_ eventPaths: [String]) {
        guard let watchedRepoRoot else { return }
        guard GitWorkspaceFSEventsPolicy.shouldRefresh(
            eventPaths: eventPaths,
            repoRoot: watchedRepoRoot
        ) else {
            return
        }
        scheduleRefresh(repoRoot: watchedRepoRoot)
    }

    private func scheduleRefresh(repoRoot: String) {
        refreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let root = self.watchedRepoRoot else { return }
            GitWorkingTreeRefreshCenter.notifyWorkingTreeMayHaveChanged(at: root)
            self.refreshWorkItem = nil
        }
        refreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
