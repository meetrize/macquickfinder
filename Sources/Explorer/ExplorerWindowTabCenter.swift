import AppKit
import SwiftUI

struct ExplorerTabBarState: Equatable {
    var isVisible: Bool
    var tabCount: Int
    var isTabbingAvailable: Bool

    static let unavailable = ExplorerTabBarState(isVisible: false, tabCount: 1, isTabbingAvailable: false)

    var canToggle: Bool {
        isTabbingAvailable && tabCount <= 1
    }
}

/// 管理 Explorer 主窗口的标签页合并、新窗口与标签总览。
@MainActor
final class ExplorerWindowTabCenter: ObservableObject {
    static let shared = ExplorerWindowTabCenter()

    enum OpenMode {
        case newWindow
    }

    private struct PendingNewTab {
        weak var sourceWindow: NSWindow?
        let sceneKind: ExplorerWindowSceneKind
        let path: String
    }

    private struct PendingOpen {
        weak var sourceWindow: NSWindow?
        let mode: OpenMode
    }

    private var pendingNewTab: PendingNewTab?
    private var pendingOpen: PendingOpen?
    private var windowPaths: [ObjectIdentifier: String] = [:]
    private var windowSceneKinds: [ObjectIdentifier: ExplorerWindowSceneKind] = [:]
    /// 主场景新建标签时，新窗口 `ContentView` 在 `onAppear` 读取并清除。
    private var pendingMainTabPaths: [ObjectIdentifier: String] = [:]
    @Published private(set) var tabBarRevision: UInt = 0
    private var notificationObservers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.bumpTabBarRevision() }
            },
            center.addObserver(forName: NSWindow.didResizeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.bumpTabBarRevision() }
            },
            center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] notification in
                guard let window = notification.object as? NSWindow else { return }
                Task { @MainActor in
                    let id = ObjectIdentifier(window)
                    self?.windowPaths.removeValue(forKey: id)
                    self?.windowSceneKinds.removeValue(forKey: id)
                }
            },
        ]
    }

    func registerWindow(_ window: NSWindow, path: String, sceneKind: ExplorerWindowSceneKind) {
        let id = ObjectIdentifier(window)
        windowPaths[id] = path
        windowSceneKinds[id] = sceneKind
    }

    func path(for window: NSWindow?) -> String? {
        guard let window else { return nil }
        return windowPaths[ObjectIdentifier(window)]
    }

    func sceneKind(for window: NSWindow?) -> ExplorerWindowSceneKind {
        guard let window else { return .main }
        return windowSceneKinds[ObjectIdentifier(window)] ?? .main
    }

    /// 主场景标签合并后，供新 `ContentView` 同步打开与源标签相同的目录。
    func consumeInitialPathForNewTab(in window: NSWindow) -> String? {
        pendingMainTabPaths.removeValue(forKey: ObjectIdentifier(window))
    }

    /// 在当前窗口组中新建标签页（与标签栏「+」一致：同场景、同路径、直接合并）。
    func openNewTab(path: String, from sourceWindow: NSWindow?) {
        let anchor = sourceWindow ?? NSApp.keyWindow
        guard let anchor else { return }

        configureExplorerWindow(anchor)

        let sceneKind = sceneKind(for: anchor)
        pendingNewTab = PendingNewTab(sourceWindow: anchor, sceneKind: sceneKind, path: path)

        switch sceneKind {
        case .main:
            ExplorerWindowOpenBridge.shared.openMainWindow?()
        case .folder:
            guard let openFolderWindow = ExplorerWindowOpenBridge.shared.openFolderWindow else {
                pendingNewTab = nil
                return
            }
            openFolderWindow(ExplorerFolderWindowValue(path: path))
        }
    }

    /// 在 `NSWindow` 挂到视图层级时尽早合并，避免独立窗口闪现。
    func attemptTabMerge(for window: NSWindow) {
        guard var pending = pendingNewTab else { return }
        guard pending.sourceWindow !== window else { return }
        guard let anchor = pending.sourceWindow else {
            pendingNewTab = nil
            return
        }

        configureExplorerWindow(window)

        if window.isVisible {
            window.orderOut(nil)
        }
        anchor.addTabbedWindow(window, ordered: .above)
        if pending.sceneKind == .main {
            pendingMainTabPaths[ObjectIdentifier(window)] = pending.path
        }
        pendingNewTab = nil
        window.makeKeyAndOrderFront(nil)
        bumpTabBarRevision()
    }

    func requestNewWindow(path: String, from sourceWindow: NSWindow?, openWindow: (ExplorerFolderWindowValue) -> Void) {
        pendingOpen = PendingOpen(sourceWindow: sourceWindow, mode: .newWindow)
        openWindow(ExplorerFolderWindowValue(path: path))
    }

    func handleExplorerWindowDidAppear(_ window: NSWindow) {
        configureExplorerWindow(window)

        guard let pendingOpen else {
            bumpTabBarRevision()
            return
        }

        guard pendingOpen.sourceWindow !== window else {
            return
        }

        guard pendingOpen.mode == .newWindow else { return }

        self.pendingOpen = nil
        window.tabGroup?.removeWindow(window)
        window.tabbingMode = .disallowed
        window.makeKeyAndOrderFront(nil)

        bumpTabBarRevision()
    }

    func configureExplorerWindow(_ window: NSWindow) {
        guard window.tabbingMode != .disallowed else { return }
        window.tabbingMode = .preferred
    }

    func showAllTabs(in window: NSWindow?) {
        window?.toggleTabOverview(nil)
    }

    static func tabBarState(for window: NSWindow?) -> ExplorerTabBarState {
        guard let window, window.tabbingMode != .disallowed else {
            return .unavailable
        }

        let tabGroup = window.tabGroup
        let tabCount = tabGroup?.windows.count ?? 1
        let isVisible = tabGroup?.isTabBarVisible ?? false
        return ExplorerTabBarState(
            isVisible: isVisible,
            tabCount: tabCount,
            isTabbingAvailable: true
        )
    }

    func toggleTabBar(in window: NSWindow?) {
        let state = Self.tabBarState(for: window)
        guard state.canToggle else { return }
        window?.toggleTabBar(nil)
        DispatchQueue.main.async { [weak self] in
            self?.bumpTabBarRevision()
        }
    }

    private func bumpTabBarRevision() {
        tabBarRevision &+= 1
    }
}
