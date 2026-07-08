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
        stop()
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
    }
    
    func stop() {
        listingRefreshWorkItem?.cancel()
        listingRefreshWorkItem = nil
        pendingListingRefresh = false
        suppressListingRefreshUntil = nil
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
    
    /// 用户主动刷新目录（如粘贴后的 `loadItems`）期间抑制 FSEvents 触发的重复全量 reload。
    func noteUserInitiatedListingRefresh(suppressFor duration: TimeInterval = 0.8) {
        let until = Date().addingTimeInterval(duration)
        if let existing = suppressListingRefreshUntil {
            suppressListingRefreshUntil = max(existing, until)
        } else {
            suppressListingRefreshUntil = until
        }
    }

    private func shouldSuppressListingRefresh() -> Bool {
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
            guard !shouldSuppressListingRefresh() else { break }
            onListingPatch?(patch)
        case .requiresFullReload:
            if DirectoryListingFSEventsPolicy.listingAffectedByEvents(
                eventPaths: events.map(\.path),
                directoryPath: watchedDirectoryPath
            ) {
                scheduleListingRefresh()
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
    
    private func scheduleListingRefresh() {
        guard !shouldSuppressListingRefresh() else { return }
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
