import AppKit
import Foundation

@MainActor
enum ExternalPreviewOpenForwarder {
    private static var isInstalled = false

    static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        DistributedNotificationCenter.default().addObserver(
            forName: MeoFindDocumentOpenerConstants.previewOpenNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let paths = notification.userInfo?[MeoFindDocumentOpenerConstants.previewOpenPathsKey] as? [String] else {
                return
            }
            let urls = paths.map { URL(fileURLWithPath: $0) }
            Task { @MainActor in
                _ = ExternalPreviewOpenCenter.shared.tryOpen(urls: urls)
            }
        }
    }
}
