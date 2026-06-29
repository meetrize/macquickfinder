import AppKit
import SwiftUI

@MainActor
enum ToolbarCustomizationWindowController {
    private static var customizationWindow: NSWindow?
    private static var delegateHolder: WindowDelegate?

    static var activeWindow: NSWindow? { customizationWindow }

    static func present(
        store: ToolbarCustomizationStore,
        environment: ExplorerToolbarEnvironment,
        parentWindow: NSWindow?
    ) {
        if let customizationWindow, customizationWindow.isVisible {
            ToolbarWindowPlacement.attachAsChild(customizationWindow, to: parentWindow)
            customizationWindow.makeKeyAndOrderFront(nil)
            customizationWindow.makeFirstResponder(nil)
            return
        }

        store.beginCustomization()

        let rootView = ToolbarCustomizationPanelView(
            store: store,
            environment: environment,
            onFinish: { dismiss() }
        )

        let hostingView = NSHostingView(rootView: rootView)
        let windowSize = NSSize(width: 600, height: 168)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = L10n.Toolbar.customizeTitle
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        let delegate = WindowDelegate(store: store, parentWindow: parentWindow) {
            customizationWindow = nil
            delegateHolder = nil
        }
        window.delegate = delegate
        delegateHolder = delegate

        ToolbarWindowPlacement.center(window, size: windowSize, relativeTo: parentWindow)
        ToolbarWindowPlacement.attachAsChild(window, to: parentWindow)

        customizationWindow = window
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func dismiss() {
        ToolbarOpenAppEditorWindowController.dismiss()
        guard let window = customizationWindow else { return }
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }
        window.close()
        customizationWindow = nil
        delegateHolder = nil
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        private let store: ToolbarCustomizationStore
        private let onClosed: () -> Void
        private var parentCloseObserver: NSObjectProtocol?

        init(
            store: ToolbarCustomizationStore,
            parentWindow: NSWindow?,
            onClosed: @escaping () -> Void
        ) {
            self.store = store
            self.onClosed = onClosed
            super.init()

            guard let parentWindow else { return }
            parentCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: parentWindow,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    ToolbarCustomizationWindowController.dismiss()
                }
            }
        }

        func windowWillClose(_ notification: Notification) {
            ToolbarOpenAppEditorWindowController.dismiss()
            if store.isCustomizing {
                store.cancelCustomization()
            }
            onClosed()
        }

        deinit {
            if let parentCloseObserver {
                NotificationCenter.default.removeObserver(parentCloseObserver)
            }
        }
    }
}
