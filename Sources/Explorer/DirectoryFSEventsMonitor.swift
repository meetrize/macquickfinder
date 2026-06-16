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
    private var onListingRefresh: (() -> Void)?
    
    private var pendingListingRefresh = false
    private var listingRefreshWorkItem: DispatchWorkItem?
    
    private var pendingAffectedPaths: Set<String> = []
    private var sizeInvalidateWorkItem: DispatchWorkItem?
    
    private init() {}
    
    func updateSession(
        directoryPath: String,
        folderPaths: [String],
        showHiddenFiles: Bool,
        autoCalculateDirectorySizes: Bool,
        onListingRefresh: @escaping () -> Void
    ) {
        stop()
        guard !directoryPath.isEmpty else { return }
        guard DirectorySizeVolumeFilter.shouldAutoCalculate(path: directoryPath) else { return }
        
        self.watchedDirectoryPath = directoryPath
        self.listedFolderPaths = Set(folderPaths)
        self.showHiddenFiles = showHiddenFiles
        self.autoCalculateDirectorySizes = autoCalculateDirectorySizes
        self.onListingRefresh = onListingRefresh
        
        watcher = DirectoryFSEventsWatcher { [weak self] eventPaths in
            Task { @MainActor in
                self?.handleEventPaths(eventPaths)
            }
        }
        watcher?.start(path: directoryPath)
    }
    
    func stop() {
        listingRefreshWorkItem?.cancel()
        listingRefreshWorkItem = nil
        pendingListingRefresh = false
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
    
    private func handleEventPaths(_ eventPaths: [String]) {
        guard let watchedDirectoryPath else { return }
        
        if DirectoryListingFSEventsPolicy.listingAffectedByEvents(
            eventPaths: eventPaths,
            directoryPath: watchedDirectoryPath
        ) {
            scheduleListingRefresh()
        }
        
        guard autoCalculateDirectorySizes else { return }
        let affected = DirectorySizeComputePolicy.foldersAffectedByEvents(
            eventPaths: eventPaths,
            listedFolderPaths: listedFolderPaths
        )
        guard !affected.isEmpty else { return }
        pendingAffectedPaths.formUnion(affected)
        scheduleSizeInvalidation()
    }
    
    private func scheduleListingRefresh() {
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
            await DirectorySizeService.shared.invalidate(paths: paths)
            await MainActor.run {
                DirectorySizeOverlay.shared.remove(paths: paths)
            }
            guard DirectorySizePreferences.autoCalculateDirectorySizes else { return }
            await DirectorySizeService.shared.schedule(
                paths: paths,
                showHiddenFiles: showHidden,
                priority: .visible
            )
        }
    }
}
