import AppKit
import Foundation

@MainActor
final class PreviewSessionStore: ObservableObject {
    static let shared = PreviewSessionStore()

    @Published private(set) var sessions: [PreviewSessionID: PreviewSession] = [:]

    private init() {}

    func register(_ session: PreviewSession) {
        sessions[session.id] = session
    }

    func session(for id: PreviewSessionID) -> PreviewSession? {
        sessions[id]
    }

    func remove(_ id: PreviewSessionID) {
        if let session = sessions[id] {
            session.cancelLoad()
            session.clearBrowserContext()
            session.clearLoadedContent()
        }
        sessions[id] = nil
    }

    func sessions(forHostWindowID hostWindowID: UUID) -> [PreviewSession] {
        sessions.values.filter { $0.hostWindowID == hostWindowID }
    }

    func detachedSession(forHostWindowID hostWindowID: UUID) -> PreviewSession? {
        sessions.values.first { $0.hostWindowID == hostWindowID && $0.location.isDetached }
    }

    func detachedSession(forFileID fileID: FileItem.ID) -> PreviewSession? {
        sessions.values.first { session in
            guard session.location.isDetached else { return false }
            if session.file.id == fileID { return true }
            if session.browseTarget.id == fileID { return true }
            return false
        }
    }

    func removeAll(forHostWindowID hostWindowID: UUID) {
        let ids = sessions.values.filter { $0.hostWindowID == hostWindowID }.map(\.id)
        ids.forEach { remove($0) }
    }

    /// 侧栏关闭预览等场景：仅移除仍挂载在内联面板的会话，保留已分离窗口会话。
    func removeInlineSessions(forHostWindowID hostWindowID: UUID) {
        let ids = sessions.values.filter {
            $0.hostWindowID == hostWindowID && !$0.location.isDetached
        }.map(\.id)
        ids.forEach { remove($0) }
    }

    func existingInlineSession(hostWindowID: UUID, fileID: FileItem.ID) -> PreviewSession? {
        sessions.values.first { session in
            session.hostWindowID == hostWindowID
                && session.file.id == fileID
                && session.folderInlineChild == nil
                && !session.location.isDetached
        }
    }

    func existingInlineSession(hostWindowID: UUID, browseTargetID: FileItem.ID) -> PreviewSession? {
        sessions.values.first { session in
            session.hostWindowID == hostWindowID
                && session.browseTarget.id == browseTargetID
                && !session.location.isDetached
        }
    }

    func inlineSessionWithUnsavedTextEdits(hostWindowID: UUID) -> PreviewSession? {
        sessions.values.first { session in
            session.hostWindowID == hostWindowID
                && !session.location.isDetached
                && session.text.isEditing
                && session.text.hasUnsavedChanges
        }
    }

    /// 系统内存压力：取消预取与进行中的加载；非 key 的 detached 会话释放已解码内容。
    /// - Parameter clearInline: critical 时连内联预览也释放已解码内容。
    func respondToMemoryPressure(clearInline: Bool = false) {
        let keyWindow = NSApp.keyWindow
        for session in sessions.values {
            session.browseContentPrefetcher.cancel()
            session.cancelLoad()
            if shouldClearLoadedContent(for: session, keyWindow: keyWindow, clearInline: clearInline) {
                session.clearLoadedContent()
            }
        }
    }

    private func shouldClearLoadedContent(
        for session: PreviewSession,
        keyWindow: NSWindow?,
        clearInline: Bool
    ) -> Bool {
        if !session.location.isDetached {
            return clearInline
        }
        let title = session.browseTarget.name
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.title == title }) else {
            return true
        }
        return window !== keyWindow
    }
}
