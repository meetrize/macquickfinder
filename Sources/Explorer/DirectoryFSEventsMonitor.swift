import Foundation
import FileList

@MainActor
final class DirectoryFSEventsMonitor {
    static let shared = DirectoryFSEventsMonitor()
    
    private var watcher: DirectoryFSEventsWatcher?
    private var listedFolderPaths: Set<String> = []
    private var showHiddenFiles = false
    private var watchedDirectoryPath: String?
    private var autoCalculateDirectorySizes = false
    private var onListingPatch: ((DirectoryListingIncrementalPatcher.Patch) -> Void)?
    private var onListingRefresh: (() -> Void)?
    
    private var pendingListingRefresh = false
    private var listingRefreshWorkItem: DispatchWorkItem?
    private var suppressListingRefreshUntil: Date?
    private var suppressEndedWorkItem: DispatchWorkItem?
    
    private var pendingAffectedPaths: Set<String> = []
    private var sizeInvalidateWorkItem: DispatchWorkItem?
    
    private init() {}
    
    func updateSession(
        directoryPath: String,
        folderPaths: [String],
        showHiddenFiles: Bool,
        autoCalculateDirectorySizes: Bool,
        onListingPatch: @escaping (DirectoryListingIncrementalPatcher.Patch) -> Void,
        onListingRefresh: @escaping () -> Void
    ) {
        // 重启会话时保留「需要全量 reload」意图，避免新建文件夹触发的 restart 吞掉待处理删除/移动。
        let shouldReplayPendingRefresh = pendingListingRefresh
        stopWatcherPreservingListingIntent()
        
        guard !directoryPath.isEmpty else { return }
        guard DirectorySizeVolumeFilter.shouldAutoCalculate(path: directoryPath) else { return }
        
        self.watchedDirectoryPath = directoryPath
        self.listedFolderPaths = Set(folderPaths)
        self.showHiddenFiles = showHiddenFiles
        self.autoCalculateDirectorySizes = autoCalculateDirectorySizes
        self.onListingPatch = onListingPatch
        self.onListingRefresh = onListingRefresh
        
        watcher = DirectoryFSEventsWatcher { [weak self] events in
            Task { @MainActor in
                self?.handleEvents(events)
            }
        }
        watcher?.start(path: directoryPath)
        
        if shouldReplayPendingRefresh {
            scheduleListingRefresh(force: true)
        }
    }
    
    func stop() {
        listingRefreshWorkItem?.cancel()
        listingRefreshWorkItem = nil
        pendingListingRefresh = false
        suppressListingRefreshUntil = nil
        suppressEndedWorkItem?.cancel()
        suppressEndedWorkItem = nil
        onListingPatch = nil
        onListingRefresh = nil
        
        sizeInvalidateWorkItem?.cancel()
        sizeInvalidateWorkItem = nil
        pendingAffectedPaths.removeAll()
        
        watcher?.stop()
        watcher = nil
        listedFolderPaths.removeAll()
        watchedDirectoryPath = nil
        autoCalculateDirectorySizes = false
    }
    
    /// 用户主动刷新目录（如粘贴后的增量插入）期间，仅抑制「纯新增」回声，不丢弃删除/移动。
    func noteUserInitiatedListingRefresh(suppressFor duration: TimeInterval = 0.8) {
        let until = Date().addingTimeInterval(duration)
        if let existing = suppressListingRefreshUntil {
            suppressListingRefreshUntil = max(existing, until)
        } else {
            suppressListingRefreshUntil = until
        }
        scheduleSuppressEndFlush(at: suppressListingRefreshUntil!)
    }

    private func shouldSuppressAdditiveListingUpdates() -> Bool {
        guard let until = suppressListingRefreshUntil else { return false }
        if Date() < until { return true }
        suppressListingRefreshUntil = nil
        return false
    }

    private func handleEvents(_ events: [DirectoryFSEvent]) {
        guard let watchedDirectoryPath else { return }

        switch DirectoryListingIncrementalPatcher.evaluate(
            events: events,
            directoryPath: watchedDirectoryPath
        ) {
        case .noListingChange:
            break
        case .patch(let patch):
            deliverPatch(patch)
        case .requiresFullReload:
            if DirectoryListingFSEventsPolicy.listingAffectedByEvents(
                eventPaths: events.map(\.path),
                directoryPath: watchedDirectoryPath
            ) {
                // 删除/移走/重命名常表现为 Renamed → 全量 reload，禁止被粘贴抑制窗吞掉。
                scheduleListingRefresh(force: true)
            }
        }
        
        guard autoCalculateDirectorySizes else { return }
        let affected = DirectorySizeComputePolicy.foldersAffectedByEvents(
            eventPaths: events.map(\.path),
            listedFolderPaths: listedFolderPaths
        )
        guard !affected.isEmpty else { return }
        pendingAffectedPaths.formUnion(affected)
        scheduleSizeInvalidation()
    }

    private func deliverPatch(_ patch: DirectoryListingIncrementalPatcher.Patch) {
        guard !patch.isEmpty else { return }
        // 抑制窗只挡「纯新增」（粘贴回声）；带 removed 的补丁始终投递。
        if shouldSuppressAdditiveListingUpdates(), patch.removedPaths.isEmpty {
            return
        }
        onListingPatch?(patch)
    }
    
    private func scheduleListingRefresh(force: Bool = false) {
        if !force, shouldSuppressAdditiveListingUpdates() {
            pendingListingRefresh = true
            return
        }
        pendingListingRefresh = true
        listingRefreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.flushListingRefresh()
        }
        listingRefreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    
    private func flushListingRefresh() {
        guard pendingListingRefresh else { return }
        pendingListingRefresh = false
        listingRefreshWorkItem = nil
        onListingRefresh?()
    }

    private func scheduleSuppressEndFlush(at until: Date) {
        suppressEndedWorkItem?.cancel()
        let delay = max(0, until.timeIntervalSinceNow) + 0.05
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.suppressListingRefreshUntil = nil
            if self.pendingListingRefresh {
                self.scheduleListingRefresh(force: true)
            }
        }
        suppressEndedWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// 停止 watcher，但保留 pending 全量 reload 与抑制窗（供 updateSession 重放）。
    private func stopWatcherPreservingListingIntent() {
        listingRefreshWorkItem?.cancel()
        listingRefreshWorkItem = nil
        // pendingListingRefresh 有意保留
        onListingPatch = nil
        onListingRefresh = nil
        
        sizeInvalidateWorkItem?.cancel()
        sizeInvalidateWorkItem = nil
        pendingAffectedPaths.removeAll()
        
        watcher?.stop()
        watcher = nil
        listedFolderPaths.removeAll()
        watchedDirectoryPath = nil
        autoCalculateDirectorySizes = false
    }
    
    private func scheduleSizeInvalidation() {
        sizeInvalidateWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.flushPendingInvalidations()
        }
        sizeInvalidateWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    
    private func flushPendingInvalidations() {
        let paths = Array(pendingAffectedPaths)
        pendingAffectedPaths.removeAll()
        sizeInvalidateWorkItem = nil
        guard !paths.isEmpty else { return }
        
        let showHidden = showHiddenFiles
        Task {
            await DirectoryMetadataScheduler.rescheduleAfterFSEventsInvalidation(
                paths: paths,
                showHiddenFiles: showHidden
            )
        }
    }
}
