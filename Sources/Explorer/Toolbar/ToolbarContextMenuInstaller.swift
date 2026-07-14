import AppKit
import SwiftUI

/// 在窗口 unified toolbar 区域拦截右键：
/// - 正常模式：弹出「自定义工具栏…」
/// - 自定义模式：在自定义打开应用 / 快捷方式图标上弹出编辑或删除
struct ToolbarContextMenuInstaller: NSViewRepresentable {
    @Binding var hostWindow: NSWindow?
    @ObservedObject var store: ToolbarCustomizationStore
    let onCustomize: () -> Void
    let onEditOpenApp: (CustomOpenAppAction) -> Void
    let onDeleteOpenApp: (CustomOpenAppAction) -> Void
    let onDeleteOpenShortcut: (CustomOpenShortcutAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            store: store,
            onCustomize: onCustomize,
            onEditOpenApp: onEditOpenApp,
            onDeleteOpenApp: onDeleteOpenApp,
            onDeleteOpenShortcut: onDeleteOpenShortcut
        )
    }

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.onWindowChange = { [weak coordinator = context.coordinator] in
            coordinator?.syncMonitor(targetWindow: coordinator?.anchorView?.window)
        }
        context.coordinator.anchorView = view
        return view
    }

    func updateNSView(_ nsView: AnchorView, context: Context) {
        context.coordinator.anchorView = nsView
        context.coordinator.store = store
        context.coordinator.onCustomize = onCustomize
        context.coordinator.onEditOpenApp = onEditOpenApp
        context.coordinator.onDeleteOpenApp = onDeleteOpenApp
        context.coordinator.onDeleteOpenShortcut = onDeleteOpenShortcut
        context.coordinator.syncMonitor(targetWindow: hostWindow ?? nsView.window)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitor()
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var anchorView: NSView?
        var store: ToolbarCustomizationStore
        var onCustomize: () -> Void
        var onEditOpenApp: (CustomOpenAppAction) -> Void
        var onDeleteOpenApp: (CustomOpenAppAction) -> Void
        var onDeleteOpenShortcut: (CustomOpenShortcutAction) -> Void
        private var monitor: Any?
        private weak var monitoredWindow: NSWindow?

        init(
            store: ToolbarCustomizationStore,
            onCustomize: @escaping () -> Void,
            onEditOpenApp: @escaping (CustomOpenAppAction) -> Void,
            onDeleteOpenApp: @escaping (CustomOpenAppAction) -> Void,
            onDeleteOpenShortcut: @escaping (CustomOpenShortcutAction) -> Void
        ) {
            self.store = store
            self.onCustomize = onCustomize
            self.onEditOpenApp = onEditOpenApp
            self.onDeleteOpenApp = onDeleteOpenApp
            self.onDeleteOpenShortcut = onDeleteOpenShortcut
        }

        func syncMonitor(targetWindow: NSWindow?) {
            let resolvedWindow = targetWindow ?? anchorView?.window
            guard resolvedWindow !== monitoredWindow else { return }
            stopMonitor()
            monitoredWindow = resolvedWindow
            guard resolvedWindow != nil else { return }
            startMonitor()
        }

        func startMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                self?.handleRightMouseDown(event) ?? event
            }
        }

        func stopMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handleRightMouseDown(_ event: NSEvent) -> NSEvent? {
            guard let window = event.window else { return event }
            guard window === monitoredWindow || window === anchorView?.window else { return event }
            guard ToolbarContextMenuHitTesting.isToolbarClick(event, in: window) else { return event }

            if store.isCustomizing {
                return handleCustomizingRightClick(event, in: window)
            }

            let menu = NSMenu()
            let item = NSMenuItem(
                title: L10n.Toolbar.customize,
                action: #selector(handleCustomizeMenuItem),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)

            popUp(menu, for: event, in: window)
            return nil
        }

        private func handleCustomizingRightClick(_ event: NSEvent, in window: NSWindow) -> NSEvent? {
            let workingLayout = store.workingLayout
            guard let itemID = ToolbarContextMenuHitTesting.toolbarItemID(
                at: event.locationInWindow,
                in: window
            ) else {
                // 放行给 SwiftUI chip 上的 .contextMenu（新拖入项 Frame 可能尚未就绪）。
                return event
            }

            if let action = workingLayout.customAction(for: itemID) {
                let menu = NSMenu()
                let editItem = NSMenuItem(
                    title: L10n.Toolbar.openAppEdit,
                    action: #selector(handleEditOpenAppItem(_:)),
                    keyEquivalent: ""
                )
                editItem.target = self
                editItem.representedObject = action.id.uuidString
                menu.addItem(editItem)

                let deleteItem = NSMenuItem(
                    title: L10n.Action.delete,
                    action: #selector(handleDeleteOpenAppItem(_:)),
                    keyEquivalent: ""
                )
                deleteItem.target = self
                deleteItem.representedObject = action.id.uuidString
                menu.addItem(deleteItem)

                popUp(menu, for: event, in: window)
                return nil
            }

            if let shortcut = workingLayout.customShortcut(for: itemID) {
                let menu = NSMenu()
                let deleteItem = NSMenuItem(
                    title: L10n.Action.delete,
                    action: #selector(handleDeleteOpenShortcutItem(_:)),
                    keyEquivalent: ""
                )
                deleteItem.target = self
                deleteItem.representedObject = shortcut.id.uuidString
                menu.addItem(deleteItem)

                popUp(menu, for: event, in: window)
                return nil
            }

            return event
        }

        private func popUp(_ menu: NSMenu, for event: NSEvent, in window: NSWindow) {
            let popupTarget = ToolbarContextMenuHitTesting.hitView(at: event.locationInWindow, in: window)
                ?? window.contentView
            if let popupTarget {
                NSMenu.popUpContextMenu(menu, with: event, for: popupTarget)
            }
        }

        @objc private func handleCustomizeMenuItem() {
            onCustomize()
        }

        @objc private func handleEditOpenAppItem(_ sender: NSMenuItem) {
            guard let rawID = sender.representedObject as? String,
                  let actionID = UUID(uuidString: rawID),
                  let action = store.workingLayout.customOpenApps.first(where: { $0.id == actionID }) else {
                return
            }
            onEditOpenApp(action)
        }

        @objc private func handleDeleteOpenAppItem(_ sender: NSMenuItem) {
            guard let rawID = sender.representedObject as? String,
                  let actionID = UUID(uuidString: rawID),
                  let action = store.workingLayout.customOpenApps.first(where: { $0.id == actionID }) else {
                return
            }
            onDeleteOpenApp(action)
        }

        @objc private func handleDeleteOpenShortcutItem(_ sender: NSMenuItem) {
            guard let rawID = sender.representedObject as? String,
                  let actionID = UUID(uuidString: rawID),
                  let action = store.workingLayout.customOpenShortcuts.first(where: { $0.id == actionID }) else {
                return
            }
            onDeleteOpenShortcut(action)
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

enum ToolbarContextMenuHitTesting {
    private static let toolbarMarkers = [
        "NSToolbar",
        "_NSToolbar",
        "ToolbarButton",
        "NSToolbarItemViewer",
    ]

    static func isToolbarClick(_ event: NSEvent, in window: NSWindow) -> Bool {
        if isWindowControlClick(event, in: window) { return false }
        if window.toolbar?.isVisible == false { return false }

        if let hitView = hitView(at: event.locationInWindow, in: window),
           isInsideToolbar(hitView) {
            return true
        }
        return isInTitlebarToolbarRegion(event, in: window)
    }

    static func hitView(at locationInWindow: NSPoint, in window: NSWindow) -> NSView? {
        guard let root = window.contentView?.superview else { return nil }
        let point = root.convert(locationInWindow, from: nil)
        return root.hitTest(point)
    }

    static func toolbarItemID(at locationInWindow: NSPoint, in window: NSWindow) -> String? {
        if let itemID = ToolbarItemFrameRegistry.shared.itemID(at: locationInWindow) {
            return itemID
        }

        guard let hitView = hitView(at: locationInWindow, in: window) else { return nil }
        return accessibilityToolbarItemID(startingAt: hitView)
    }

    private static func accessibilityToolbarItemID(startingAt view: NSView) -> String? {
        if let itemID = itemID(from: view.accessibilityIdentifier()) {
            return itemID
        }

        var current: NSView? = view.superview
        while let node = current {
            if let itemID = itemID(from: node.accessibilityIdentifier()) {
                return itemID
            }
            current = node.superview
        }

        return nil
    }

    private static func itemID(from accessibilityIdentifier: String?) -> String? {
        guard let accessibilityIdentifier else { return nil }
        return ToolbarItemIdentity.itemID(fromAccessibilityIdentifier: accessibilityIdentifier)
    }

    private static func isInsideToolbar(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let node = current {
            let name = String(describing: type(of: node))
            if toolbarMarkers.contains(where: { name.contains($0) }) {
                return true
            }
            if name.contains("_SwiftUI"), ancestorContainsToolbarMarker(from: node) {
                return true
            }
            current = node.superview
        }
        return false
    }

    private static func ancestorContainsToolbarMarker(from view: NSView) -> Bool {
        var current: NSView? = view
        while let node = current {
            let name = String(describing: type(of: node))
            if toolbarMarkers.contains(where: { name.contains($0) }) {
                return true
            }
            current = node.superview
        }
        return false
    }

    private static func isWindowControlClick(_ event: NSEvent, in window: NSWindow) -> Bool {
        let location = event.locationInWindow
        for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(kind) else { continue }
            let point = button.convert(location, from: nil)
            if button.bounds.contains(point) {
                return true
            }
        }
        return false
    }

    private static func isInTitlebarToolbarRegion(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard let root = window.contentView?.superview else { return false }
        let point = root.convert(event.locationInWindow, from: nil)
        let titlebarHeight: CGFloat = window.toolbar?.sizeMode == .regular ? 52 : 38
        guard point.y >= root.bounds.height - titlebarHeight else { return false }

        let trafficLightsReservedWidth: CGFloat = 78
        guard point.x >= trafficLightsReservedWidth else { return false }
        return true
    }
}

final class AnchorView: NSView {
    var onWindowChange: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?()
    }
}
