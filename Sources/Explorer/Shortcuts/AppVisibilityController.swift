import AppKit

@MainActor
enum AppVisibilityController {
    static func toggle() {
        let app = NSApplication.shared
        let shouldHide = app.isActive
            && !app.isHidden
            && app.keyWindow?.isMiniaturized != true

        if shouldHide {
            app.hide(nil)
            return
        }

        app.unhide(nil)
        app.activate(ignoringOtherApps: true)

        if let window = app.windows.first(where: { $0.isVisible && !$0.isMiniaturized && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        if let window = app.windows.first(where: { $0.canBecomeKey }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
