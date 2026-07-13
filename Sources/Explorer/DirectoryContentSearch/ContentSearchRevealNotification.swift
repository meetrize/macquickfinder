import Foundation

struct ContentSearchRevealRequest: Equatable {
    let hostWindowID: UUID
    let fileID: String
    let lineNumber: Int
    let query: String
}

extension Notification.Name {
    static let contentSearchRevealMatch = Notification.Name("explorer.contentSearchRevealMatch")
    static let findInFolderRequested = Notification.Name("explorer.findInFolderRequested")
}

enum ContentSearchRevealNotification {
    private static let hostWindowIDKey = "hostWindowID"
    private static let fileIDKey = "fileID"
    private static let lineNumberKey = "lineNumber"
    private static let queryKey = "query"
    private static var pendingByHost: [UUID: ContentSearchRevealRequest] = [:]

    static func prepareReveal(_ request: ContentSearchRevealRequest) {
        pendingByHost[request.hostWindowID] = request
        post(request)
    }

    static func pending(for hostWindowID: UUID, fileID: String) -> ContentSearchRevealRequest? {
        guard let request = pendingByHost[hostWindowID], request.fileID == fileID else {
            return nil
        }
        return request
    }

    static func clearPending(for hostWindowID: UUID) {
        pendingByHost.removeValue(forKey: hostWindowID)
    }

    static func post(_ request: ContentSearchRevealRequest) {
        NotificationCenter.default.post(
            name: .contentSearchRevealMatch,
            object: nil,
            userInfo: [
                hostWindowIDKey: request.hostWindowID.uuidString,
                fileIDKey: request.fileID,
                lineNumberKey: request.lineNumber,
                queryKey: request.query,
            ]
        )
    }

    static func request(from notification: Notification) -> ContentSearchRevealRequest? {
        guard let userInfo = notification.userInfo,
              let hostWindowIDString = userInfo[hostWindowIDKey] as? String,
              let hostWindowID = UUID(uuidString: hostWindowIDString),
              let fileID = userInfo[fileIDKey] as? String,
              let lineNumber = userInfo[lineNumberKey] as? Int,
              let query = userInfo[queryKey] as? String else {
            return nil
        }
        return ContentSearchRevealRequest(
            hostWindowID: hostWindowID,
            fileID: fileID,
            lineNumber: lineNumber,
            query: query
        )
    }
}
