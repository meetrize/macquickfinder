import AppKit
import SwiftUI

@MainActor
final class HelpWindowPresenter: NSObject {
    static let shared = HelpWindowPresenter()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        if let window {
            refreshContent(in: window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = makeWindow()
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1_200
        let initialWidth = HelpCheatSheetLayoutEngine.preferredWindowWidth(forScreenWidth: screenWidth)
        let initialSize = NSSize(width: initialWidth, height: 640)
        let newWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        newWindow.delegate = self
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        refreshContent(in: newWindow)
        return newWindow
    }

    private func refreshContent(in window: NSWindow) {
        window.title = L10n.Help.windowTitle
        let rootView = HelpCheatSheetView()
            .applyInterfaceLanguageEnvironment()
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
    }
}

extension HelpWindowPresenter: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
