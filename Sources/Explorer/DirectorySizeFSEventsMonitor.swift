import Foundation
import FileList

@MainActor
final class DirectorySizeFSEventsMonitor {
    static let shared = DirectorySizeFSEventsMonitor()
    
    private var watcher: DirectoryFSEventsWatcher?
    private var listedFolderPaths: Set<String> = []
    private var showHiddenFiles = false
    private var watchedDirectoryPath: String?
    private var pendingAffectedPaths: Set<String> = []
    private var invalidateWorkItem: DispatchWorkItem?
    
    private init() {}
    
    func updateSession(
        directoryPath: String,
        folderPaths: [String],
        showHiddenFiles: Bool,
        autoCalculate: Bool
    ) {
        stop()
        guard autoCalculate else { return }
        guard DirectorySizeVolumeFilter.shouldAutoCalculate(path: directoryPath) else { return }
        guard !directoryPath.isEmpty else { return }
        
        self.watchedDirectoryPath = directoryPath
        self.listedFolderPaths = Set(folderPaths)
        self.showHiddenFiles = showHiddenFiles
        
        watcher = DirectoryFSEventsWatcher { [weak self] eventPaths in
            Task { @MainActor in
                self?.handleEventPaths(eventPaths)
            }
        }
        watcher?.start(path: directoryPath)
    }
    
    func stop() {
        invalidateWorkItem?.cancel()
        invalidateWorkItem = nil
        pendingAffectedPaths.removeAll()
        watcher?.stop()
        watcher = nil
        listedFolderPaths.removeAll()
        watchedDirectoryPath = nil
    }
    
    private func handleEventPaths(_ eventPaths: [String]) {
        let affected = DirectorySizeComputePolicy.foldersAffectedByEvents(
            eventPaths: eventPaths,
            listedFolderPaths: listedFolderPaths
        )
        guard !affected.isEmpty else { return }
        pendingAffectedPaths.formUnion(affected)
        
        invalidateWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.flushPendingInvalidations()
        }
        invalidateWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    
    private func flushPendingInvalidations() {
        let paths = Array(pendingAffectedPaths)
        pendingAffectedPaths.removeAll()
        invalidateWorkItem = nil
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
