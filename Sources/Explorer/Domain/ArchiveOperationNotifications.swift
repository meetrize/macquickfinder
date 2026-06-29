import Foundation

extension Notification.Name {
    static let archiveOperationCompleted = Notification.Name("archiveOperationCompleted")
}

enum ArchiveOperationNotifications {
    static let resultPathsKey = "resultPaths"

    static func postCompleted(resultPaths: [String]) {
        NotificationCenter.default.post(
            name: .archiveOperationCompleted,
            object: nil,
            userInfo: [resultPathsKey: resultPaths]
        )
    }
}
