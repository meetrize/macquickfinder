import AppKit
import SwiftUI

@MainActor
final class PreviewDetachCoordinator: ObservableObject {
    static let shared = PreviewDetachCoordinator()

    @Published private(set) var placement: PreviewPlacement = .inline

    private var detachedWindow: NSWindow?
    private var isDockingBackSessionID: PreviewSessionID?

    private init() {}

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

    /// 从 Finder 等外部入口直接打开图片独立预览窗。
    @discardableResult
    func openStandaloneImagePreview(
        file: FileItem,
        directoryPath: String,
        directoryItems: [FileItem]
    ) -> PreviewSessionID {
        let hostWindowID = UUID()
        let session = PreviewSession(hostWindowID: hostWindowID, file: file)
        session.allowsDockBack = false
        session.location = .detached(windowNumber: nil)
        session.isBrowserStripExpanded = true
        session.image.zoomScale = 1.0

        if let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: directoryPath,
            items: directoryItems,
            sortOrder: .nameAscending,
            showHiddenFiles: false,
            currentFileID: file.id
        ) {
            session.attachBrowserContext(context)
        }

        PreviewSessionStore.shared.register(session)
        return session.id
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
