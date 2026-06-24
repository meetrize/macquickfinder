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

    func existingInlineSession(hostWindowID: UUID, fileID: FileItem.ID) -> PreviewSession? {
        sessions.values.first { session in
            session.hostWindowID == hostWindowID
                && session.file.id == fileID
                && session.folderInlineChild == nil
                && !session.location.isDetached
        }
    }
}
