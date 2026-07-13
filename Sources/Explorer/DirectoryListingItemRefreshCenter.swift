import Foundation

extension Notification.Name {
    static let directoryListingItemDidChange = Notification.Name("DirectoryListingItemDidChange")
}

enum DirectoryListingItemRefreshCenter {
    static let pathUserInfoKey = "path"

    static func notifyItemDidChange(at url: URL) {
        NotificationCenter.default.post(
            name: .directoryListingItemDidChange,
            object: nil,
            userInfo: [pathUserInfoKey: url.path]
        )
    }
}
