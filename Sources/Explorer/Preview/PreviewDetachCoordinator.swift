import AppKit
import FileList
import SwiftUI

struct DirectoryItemsInvalidatedEvent: Equatable {
    let hostWindowID: UUID
    let directoryPath: String
    let invalidatedPaths: [String]
}

struct PreviewRevealInHostEvent: Equatable {
    let hostWindowID: UUID
    let directoryPath: String
    let selectionPath: String
}

@MainActor
final class PreviewDetachCoordinator: ObservableObject {
    static let shared = PreviewDetachCoordinator()

    @Published private(set) var placement: PreviewPlacement = .inline
    @Published private(set) var directoryItemsInvalidatedRevision: UInt = 0
    private(set) var lastDirectoryItemsInvalidatedEvent: DirectoryItemsInvalidatedEvent?
    @Published private(set) var revealInHostRevision: UInt = 0
    private(set) var lastRevealInHostEvent: PreviewRevealInHostEvent?

    private var detachedWindow: NSWindow?
    private var isDockingBackSessionID: PreviewSessionID?

    private init() {}

    func notifyDirectoryItemsInvalidated(
        hostWindowID: UUID,
        directoryPath: String,
        invalidatedPaths: [String]
    ) {
        guard !invalidatedPaths.isEmpty else { return }
        let event = DirectoryItemsInvalidatedEvent(
            hostWindowID: hostWindowID,
            directoryPath: directoryPath,
            invalidatedPaths: invalidatedPaths
        )
        lastDirectoryItemsInvalidatedEvent = event
        directoryItemsInvalidatedRevision &+= 1
    }

    func detach(
        session: PreviewSession,
        directoryPath: String,
        directoryItems: [FileItem],
        sortOrder: SortOrder,
        showHiddenFiles: Bool,
        openWindow: OpenWindowAction
    ) {
        if case .detached(let existingID, let fileID) = placement,
           existingID == session.id || fileID == session.previewContentItem?.id {
            focusDetachedWindow()
            return
        }

        if let existing = PreviewSessionStore.shared.detachedSession(forHostWindowID: session.hostWindowID),
           existing.id != session.id {
            focusWindow(for: existing)
            return
        }

        PreviewSessionStore.shared.register(session)
        session.location = .detached(windowNumber: nil)
        session.isBrowserStripExpanded = true
        if let currentID = session.previewContentItem?.id,
           let context = PreviewBrowserContext.makeSnapshot(
               directoryPath: directoryPath,
               items: directoryItems,
               sortOrder: sortOrder,
               showHiddenFiles: showHiddenFiles,
               currentFileID: currentID
           ) {
            session.attachBrowserContext(context)
        }
        if let fileID = session.previewContentItem?.id {
            placement = .detached(sessionID: session.id, fileID: fileID)
        }

        openWindow(id: ExplorerWindowScene.preview, value: PreviewWindowValue(sessionID: session.id))
    }

    func dockBack(sessionID: PreviewSessionID, currentSelectedFileID: FileItem.ID?) async -> Bool {
        guard case .detached(let detachedID, _) = placement, detachedID == sessionID else { return false }
        guard let session = PreviewSessionStore.shared.session(for: sessionID) else { return false }

        if let currentSelectedFileID,
           let previewID = session.previewContentItem?.id,
           currentSelectedFileID != previewID {
            let confirmed = await MainActor.run { () -> Bool in
                let alert = NSAlert()
                alert.messageText = L10n.Preview.reattachTitle
                alert.informativeText = L10n.Preview.reattachMessage
                alert.alertStyle = .warning
                alert.addButton(withTitle: L10n.Preview.reattachConfirm)
                alert.addButton(withTitle: L10n.Action.cancel)
                return alert.runModal() == .alertFirstButtonReturn
            }
            guard confirmed else { return false }
        }

        session.clearBrowserContext()
        session.location = .inline
        placement = .inline
        isDockingBackSessionID = sessionID
        closeDetachedWindowIfNeeded()
        return true
    }

    func onDetachedWindowWillClose(sessionID: PreviewSessionID) {
        if isDockingBackSessionID == sessionID {
            isDockingBackSessionID = nil
            detachedWindow = nil
            return
        }
        if case .detached(let detachedID, _) = placement, detachedID == sessionID {
            placement = .inline
        }
        PreviewSessionStore.shared.remove(sessionID)
        detachedWindow = nil
    }

    /// 从 Finder 等外部入口直接打开独立预览窗。
    @discardableResult
    func openStandalonePreview(
        file: FileItem,
        directoryPath: String,
        directoryItems: [FileItem],
        sortSnapshot: FileListSortState? = nil,
        options: PreviewStandaloneOpenOptions = .externalDefault
    ) -> PreviewSessionID {
        if let existing = PreviewSessionStore.shared.detachedSession(forFileID: file.id) {
            focusDetachedSession(existing)
            return existing.id
        }

        let hostWindowID = UUID()
        let session = PreviewSession(hostWindowID: hostWindowID, file: file)
        session.allowsDockBack = options.allowsDockBack
        session.location = .detached(windowNumber: nil)
        session.isBrowserStripExpanded = true
        session.adaptImageToWindowOnResize = options.fitImageToScreen
        if options.fitImageToScreen {
            session.image.zoomScale = 1.0
        }

        let resolvedSort = sortSnapshot ?? FileListPreferencesStore.shared.preferences.sort
        if let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: directoryPath,
            items: directoryItems,
            sortSnapshot: resolvedSort,
            showHiddenFiles: false,
            currentFileID: file.id
        ) {
            session.attachBrowserContext(context)
        }

        PreviewSessionStore.shared.register(session)
        return session.id
    }

    /// 从 Finder 等外部入口直接打开图片独立预览窗。
    @discardableResult
    func openStandaloneImagePreview(
        file: FileItem,
        directoryPath: String,
        directoryItems: [FileItem],
        sortSnapshot: FileListSortState? = nil
    ) -> PreviewSessionID {
        openStandalonePreview(
            file: file,
            directoryPath: directoryPath,
            directoryItems: directoryItems,
            sortSnapshot: sortSnapshot,
            options: PreviewStandaloneOpenPreferences.options(for: file)
        )
    }

    func focusDetachedSession(_ session: PreviewSession) {
        focusWindow(for: session)
    }

    /// 激活文件管理窗并定位到当前预览文件；若无对应宿主窗口则打开浏览窗并选中。
    func revealFileInHostWindow(for session: PreviewSession) {
        let file = session.browseTarget
        guard !file.isDirectory else { return }

        let directoryPath = session.browseContext?.directoryPath
            ?? file.url.deletingLastPathComponent().path
        let event = PreviewRevealInHostEvent(
            hostWindowID: session.hostWindowID,
            directoryPath: directoryPath,
            selectionPath: file.url.path
        )
        lastRevealInHostEvent = event
        revealInHostRevision &+= 1

        NSApplication.shared.activate(ignoringOtherApps: true)

        if let hostWindow = PreviewHostWindowRegistry.shared.window(for: session.hostWindowID) {
            hostWindow.makeKeyAndOrderFront(nil)
            return
        }

        ExternalFolderOpenCenter.shared.requestOpen(urls: [file.url])
    }

    func onHostWindowWillClose(hostWindowID: UUID) {
        PreviewSessionStore.shared.removeAll(forHostWindowID: hostWindowID)
        placement = .inline
        closeDetachedWindowIfNeeded()
    }

    func updateDetachedFileID(sessionID: PreviewSessionID, fileID: FileItem.ID) {
        guard case .detached(let detachedID, _) = placement, detachedID == sessionID else { return }
        placement = .detached(sessionID: sessionID, fileID: fileID)
    }

    func focusDetachedWindow() {
        if let detachedWindow {
            detachedWindow.makeKeyAndOrderFront(nil)
            return
        }
        if case .detached(let sessionID, _) = placement,
           let session = PreviewSessionStore.shared.session(for: sessionID) {
            focusWindow(for: session)
        }
    }

    func trackDetachedWindow(_ window: NSWindow?) {
        detachedWindow = window
        if let window {
            session(for: window).map { session in
                session.location = .detached(windowNumber: window.windowNumber)
            }
        }
    }

    private func focusWindow(for session: PreviewSession) {
        let windows = NSApp.windows.filter { window in
            window.title == session.previewContentItem?.name
        }
        windows.first?.makeKeyAndOrderFront(nil)
        detachedWindow = windows.first
    }

    private func closeDetachedWindowIfNeeded() {
        detachedWindow?.close()
        detachedWindow = nil
    }

    private func session(for window: NSWindow) -> PreviewSession? {
        guard case .detached(let sessionID, _) = placement else { return nil }
        return PreviewSessionStore.shared.session(for: sessionID)
    }
}
