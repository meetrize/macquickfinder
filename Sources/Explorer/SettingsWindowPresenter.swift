import AppKit
import SwiftUI

enum SettingsWindowMetrics {
    static let defaultWidth: CGFloat = 520
    static let defaultHeight: CGFloat = 500
    static let minWidth: CGFloat = 480
    static let minHeight: CGFloat = 400
}

@MainActor
final class SettingsWindowPresenter: NSObject {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?
    private(set) var pendingPrefillExtension: String?

    private override init() {
        super.init()
    }

    func stagePrefillExtension(_ ext: String?) {
        pendingPrefillExtension = ext
    }

    func consumePendingPrefillExtension() -> String? {
        defer { pendingPrefillExtension = nil }
        return pendingPrefillExtension
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = makeWindow()
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openSettingsWindow() {
        show()
    }
}

@MainActor
private extension SettingsWindowPresenter {
    func makeWindow() -> NSWindow {
        let initialSize = NSSize(
            width: SettingsWindowMetrics.defaultWidth,
            height: SettingsWindowMetrics.defaultHeight
        )
        let newWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.delegate = self
        newWindow.title = L10n.Settings.windowTitle
        newWindow.minSize = NSSize(
            width: SettingsWindowMetrics.minWidth,
            height: SettingsWindowMetrics.minHeight
        )
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        installContent(in: newWindow)
        return newWindow
    }

    func installContent(in window: NSWindow) {
        let rootView = SettingsView()
            .applyInterfaceLanguageEnvironment()
            .frame(
                minWidth: SettingsWindowMetrics.minWidth,
                minHeight: SettingsWindowMetrics.minHeight
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
    }
}

extension SettingsWindowPresenter: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

@MainActor
func openPreviewSettings(prefillExtension: String? = nil) {
    SettingsWindowPresenter.shared.stagePrefillExtension(prefillExtension)

    if let prefillExtension, !prefillExtension.isEmpty {
        NotificationCenter.default.post(
            name: .openPreviewSettingsRequested,
            object: nil,
            userInfo: ["extension": prefillExtension]
        )
    } else {
        NotificationCenter.default.post(name: .openPreviewSettingsRequested, object: nil)
    }

    SettingsWindowPresenter.shared.openSettingsWindow()
}
