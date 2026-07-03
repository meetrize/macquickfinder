import AppKit
import Foundation

private enum OpenerConstants {
    static let previewOpenNotification = Notification.Name("com.explorer.app.external-preview-open")
    static let previewOpenPathsKey = "paths"
    static let mainAppBundleIdentifier = "com.explorer.app"
}

@main
struct MeoFindDocumentOpenerApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = DocumentOpenerAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

private final class DocumentOpenerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSApplication.shared.windows.isEmpty {
            NSApp.terminate(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        forwardPreviewOpen(urls: urls)
        NSApp.terminate(nil)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        forwardPreviewOpen(urls: urls)
        NSApp.terminate(nil)
    }

    private func forwardPreviewOpen(urls: [URL]) {
        guard !urls.isEmpty else { return }
        appendLog("forward urls=\(urls.map(\.path))")
        activateMainApplicationIfNeeded()
        let paths = urls.map(\.path)
        DistributedNotificationCenter.default().post(
            name: OpenerConstants.previewOpenNotification,
            object: nil,
            userInfo: [OpenerConstants.previewOpenPathsKey: paths]
        )
    }

    private func activateMainApplicationIfNeeded() {
        guard let mainURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: OpenerConstants.mainAppBundleIdentifier
        ) else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let group = DispatchGroup()
        group.enter()
        NSWorkspace.shared.openApplication(at: mainURL, configuration: configuration) { _, _ in
            group.leave()
        }
        _ = group.wait(timeout: .now() + 2)
    }

    private func appendLog(_ line: String) {
        let entry = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        let url = URL(fileURLWithPath: "/tmp/meofind-document-opener.log")
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(entry.utf8))
            try? handle.close()
        } else {
            try? entry.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
