import AppKit
import SwiftUI

@MainActor
enum ToolbarOpenAppEditorWindowController {
    private static var editorWindow: NSWindow?

    static func present(
        store: ToolbarCustomizationStore,
        parentWindow: NSWindow?,
        editingAction: CustomOpenAppAction? = nil
    ) {
        if let editorWindow, editorWindow.isVisible {
            dismiss()
        }

        let resolvedParent = parentWindow ?? ToolbarCustomizationWindowController.activeWindow
        let rootView = CustomOpenAppEditorSheet(
            store: store,
            editingAction: editingAction
        ) {
            dismiss()
        }

        let hostingView = NSHostingView(rootView: rootView)
        let windowSize = NSSize(width: 560, height: 420)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = editingAction == nil ? L10n.Toolbar.openAppTitle : L10n.Toolbar.openAppEditTitle
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        ToolbarWindowPlacement.center(window, size: windowSize, relativeTo: resolvedParent)
        ToolbarWindowPlacement.attachAsChild(window, to: resolvedParent)

        editorWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func dismiss() {
        guard let window = editorWindow else { return }
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }
        window.close()
        editorWindow = nil
    }
}

enum ToolbarWindowPlacement {
    static func attachAsChild(_ window: NSWindow, to parentWindow: NSWindow?) {
        guard let parentWindow else { return }
        if window.parent === parentWindow { return }
        window.parent?.removeChildWindow(window)
        parentWindow.addChildWindow(window, ordered: .above)
    }

    static func center(
        _ window: NSWindow,
        size: NSSize,
        relativeTo parentWindow: NSWindow?
    ) {
        guard let parentWindow else {
            window.center()
            return
        }
        let originX = parentWindow.frame.midX - size.width / 2
        let originY = parentWindow.frame.midY - size.height / 2
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
