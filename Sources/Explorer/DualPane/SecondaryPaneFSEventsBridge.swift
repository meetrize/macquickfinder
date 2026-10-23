import Foundation
import FileList

/// 副栏独立路径的轻量 FSEvents：与主栏路径不同时才启动；同路径依赖主栏监视。
@MainActor
final class SecondaryPaneFSEventsBridge {
    private var watcher: DirectoryFSEventsWatcher?
    private var watchedPath: String?
    private var reloadWorkItem: DispatchWorkItem?

    func update(
        secondaryPath: String,
        primaryPath: String,
        isDualPaneEnabled: Bool,
        onReload: @escaping () -> Void
    ) {
        guard isDualPaneEnabled else {
            stop()
            return
        }

        let secondary = ExternalSelectionPathMatcher.standardizedPath(secondaryPath)
        let primary = ExternalSelectionPathMatcher.standardizedPath(primaryPath)
        guard !secondary.isEmpty, secondary != primary else {
            stop()
            return
        }

        if watchedPath == secondary, watcher != nil {
            return
        }

        stop()
        watchedPath = secondary
        let bridge = self
        watcher = DirectoryFSEventsWatcher { [weak bridge] events in
            guard let bridge else { return }
            let affected = DirectoryListingFSEventsPolicy.listingAffectedByEvents(
                eventPaths: events.map(\.path),
                directoryPath: secondary
            )
            guard affected else { return }
            bridge.scheduleReload(onReload)
        }
        watcher?.start(path: secondary)
    }

    func stop() {
        reloadWorkItem?.cancel()
        reloadWorkItem = nil
        watcher?.stop()
        watcher = nil
        watchedPath = nil
    }

    private func scheduleReload(_ onReload: @escaping () -> Void) {
        reloadWorkItem?.cancel()
        let work = DispatchWorkItem {
            onReload()
        }
        reloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}
