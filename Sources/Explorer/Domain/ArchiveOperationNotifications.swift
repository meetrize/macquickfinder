import Foundation

extension Notification.Name {
    static let archiveOperationCompleted = Notification.Name("archiveOperationCompleted")
}

enum ArchiveOperationNotifications {
    static let resultPathsKey = "resultPaths"
    static let navigateIntoResultKey = "navigateIntoResult"

    static func postCompleted(resultPaths: [String], navigateIntoResult: Bool = false) {
        NotificationCenter.default.post(
            name: .archiveOperationCompleted,
            object: nil,
            userInfo: [
                resultPathsKey: resultPaths,
                navigateIntoResultKey: navigateIntoResult,
            ]
        )
    }
}
