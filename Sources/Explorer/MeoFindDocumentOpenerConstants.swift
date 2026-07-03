import CoreServices
import Foundation

enum MeoFindDocumentOpenerConstants {
    static let bundleIdentifier = "com.explorer.document-opener"
    static let helperAppName = "MeoFindDocumentOpener.app"
    static let previewOpenNotification = Notification.Name("com.explorer.app.external-preview-open")
    static let previewOpenPathsKey = "paths"
    static let mainAppBundleIdentifier = "com.explorer.app"
}

enum MeoFindDocumentOpenerBundle {
    static var bundleURL: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/Helpers/\(MeoFindDocumentOpenerConstants.helperAppName)")
    }

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: bundleURL.path)
    }

    static func registerWithLaunchServicesIfNeeded() {
        guard isAvailable else { return }
        LSRegisterURL(bundleURL as CFURL, true)
    }
}
