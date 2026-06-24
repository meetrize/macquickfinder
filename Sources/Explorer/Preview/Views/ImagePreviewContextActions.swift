import AppKit

enum ImagePreviewContextActions {
    private static let previewBundleIdentifier = "com.apple.Preview"

    @MainActor
    static func openMarkup(for url: URL) {
        if let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: previewBundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.promptsUserIfNeeded = false
            NSWorkspace.shared.open([url], withApplicationAt: previewURL, configuration: configuration)
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func copyImage(from url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = NSImage(contentsOf: url) {
            pasteboard.writeObjects([image])
        } else {
            pasteboard.writeObjects([url as NSURL])
        }
    }

    @MainActor
    static func copyPath(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    @MainActor
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @MainActor
    static func openWithDefaultApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func setAsDesktopPicture(_ url: URL) {
        guard let screen = NSScreen.main else { return }
        do {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法设为桌面图片"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
