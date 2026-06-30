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

    /// 系统内存压力：取消预取与进行中的加载；非 key 的 detached 会话释放已解码内容。
    func respondToMemoryPressure() {
        let keyWindow = NSApp.keyWindow
        for session in sessions.values {
            session.browseContentPrefetcher.cancel()
            session.cancelLoad()
            if shouldClearLoadedContent(for: session, keyWindow: keyWindow) {
                session.clearLoadedContent()
            }
        }
    }

    private func shouldClearLoadedContent(for session: PreviewSession, keyWindow: NSWindow?) -> Bool {
        guard session.location.isDetached else { return false }
        let title = session.browseTarget.name
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.title == title }) else {
            return true
        }
        return window !== keyWindow
    }
}
