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

    struct PendingMainTabNavigation {
        let path: String
        let selectionPath: String?
        /// 源标签当前目录列表；新标签首屏可直接展示，无需等待磁盘枚举。
        let itemsSnapshot: [FileItem]?
    }

    private struct PendingNewTab {
        weak var sourceWindow: NSWindow?
        let sceneKind: ExplorerWindowSceneKind
        let path: String
        let selectionPath: String?
        let itemsSnapshot: [FileItem]?
    }

    private struct PendingOpen {
        weak var sourceWindow: NSWindow?
        let mode: OpenMode
    }

    private var pendingNewTab: PendingNewTab?
    private var pendingOpen: PendingOpen?
    private var windowPaths: [ObjectIdentifier: String] = [:]
    private var windowSceneKinds: [ObjectIdentifier: ExplorerWindowSceneKind] = [:]
    /// 主场景新建标签时，新窗口 `ContentView` 在挂载 `hostWindow` 后读取并清除。
    private var pendingMainTabNavigations: [ObjectIdentifier: PendingMainTabNavigation] = [:]
    /// 已合并为标签、需吞掉随后多余的 orderFront，避免激活/失焦闪动。
    private var suppressOrderFrontWindowIDs: Set<ObjectIdentifier> = []
    /// 合并后主动 reveal 时放行 orderFront，避免被自己的拦截吞掉。
    private var isRevealingMergedTab = false
    /// 合并/收起标签栏期间锁定外框，阻止系统把窗口撑高造成闪动。
    private var frameLock: (frame: NSRect, windowTokens: Set<ObjectIdentifier>, groupTokens: Set<ObjectIdentifier>)?
    private var frameLockReleaseWorkItem: DispatchWorkItem?
    @Published private(set) var tabBarRevision: UInt = 0
    private var notificationObservers: [NSObjectProtocol] = []
    private var tabDoubleClickMonitor: Any?
    private var tabRightClickMonitor: Any?

    private init() {
        installTabDoubleClickMonitor()
        installTabRightClickMonitor()
        NSWindowSnapFrameHook.installIfNeeded()
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
                    // 关闭后标签组可能只剩 1 个：等系统更新完再隐藏标签栏。
                    self?.scheduleHideTabBarIfSingleTab(relatedTo: window)
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

    /// 主场景标签合并后，供新 `ContentView` 同步目录与外部选中项。
    func consumeInitialNavigationForNewTab(in window: NSWindow) -> PendingMainTabNavigation? {
        pendingMainTabNavigations.removeValue(forKey: ObjectIdentifier(window))
    }

    /// 新建标签的窗口尚未挂载时，预读待导航目标，避免先加载首页再跳转。
    func peekPendingNewTabNavigation() -> PendingMainTabNavigation? {
        guard let pending = pendingNewTab else { return nil }
        return PendingMainTabNavigation(
            path: pending.path,
            selectionPath: pending.selectionPath,
            itemsSnapshot: pending.itemsSnapshot
        )
    }

    var hasRegisteredWindows: Bool {
        !windowPaths.isEmpty
    }

    /// 在当前窗口组中新建标签页（工具栏 / ⌘T / 系统标签栏「+」：同场景、同路径、直接合并）。
    func openNewTab(
        path: String,
        selectionPath: String? = nil,
        itemsSnapshot: [FileItem]? = nil,
        from sourceWindow: NSWindow?
    ) {
        let anchor = sourceWindow ?? NSApp.keyWindow
        guard let anchor else { return }

        configureExplorerWindow(anchor)

        let sceneKind = sceneKind(for: anchor)
        if let existing = pendingNewTab,
           existing.sourceWindow === anchor,
           existing.sceneKind == sceneKind,
           existing.path == path,
           existing.selectionPath == selectionPath {
            return
        }

        pendingNewTab = PendingNewTab(
            sourceWindow: anchor,
            sceneKind: sceneKind,
            path: path,
            selectionPath: selectionPath,
            itemsSnapshot: itemsSnapshot
        )

        switch sceneKind {
        case .main:
            ExplorerWindowOpenBridge.shared.openMainWindow?()
        case .folder:
            guard let openFolderWindow = ExplorerWindowOpenBridge.shared.openFolderWindow else {
                pendingNewTab = nil
                return
            }
            openFolderWindow(
                ExplorerFolderWindowValue(path: path, selectionPath: selectionPath)
            )
        }
    }

    /// 窗口即将 orderFront 时拦截：把 pending 新标签直接合并进锚点窗，避免独立窗闪现。
    /// - Returns: 已处理则返回 `true`，调用方勿再走普通置前。
    @discardableResult
    func interceptOrderFrontIfPendingNewTab(_ window: NSWindow) -> Bool {
        if isRevealingMergedTab { return false }

        let windowID = ObjectIdentifier(window)
        if suppressOrderFrontWindowIDs.remove(windowID) != nil {
            // 后台合并的新标签：忽略系统多余置前，避免抢选中态造成闪动。
            return true
        }
        guard let pending = pendingNewTab else { return false }
        guard pending.sourceWindow !== window else { return false }
        guard let anchor = pending.sourceWindow else { return false }
        guard window.tabbingMode != .disallowed else { return false }
        mergeNewTabWindow(window, into: anchor, pending: pending)
        return true
    }

    /// 在 `NSWindow` 挂到视图层级时尽早合并，避免独立窗口闪现。
    func attemptTabMerge(for window: NSWindow) {
        guard let pending = pendingNewTab else { return }
        guard pending.sourceWindow !== window else { return }
        guard let anchor = pending.sourceWindow else {
            pendingNewTab = nil
            return
        }
        mergeNewTabWindow(window, into: anchor, pending: pending)
    }

    private func mergeNewTabWindow(_ window: NSWindow, into anchor: NSWindow, pending: PendingNewTab) {
        configureExplorerWindow(window)
        configureExplorerWindow(anchor)

        let preservedFrame = anchor.frame
        beginFrameLock(preservedFrame, windows: [anchor, window])

        let windowAnimation = window.animationBehavior
        let anchorAnimation = anchor.animationBehavior
        window.animationBehavior = .none
        anchor.animationBehavior = .none
        defer {
            window.animationBehavior = windowAnimation
            anchor.animationBehavior = anchorAnimation
        }

        // 整段合并放进零时长动画组，中间态尽量不单独上屏。
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false

            // 新窗尚未成为选中标签前不要 orderOut，避免牵连整组标签窗。
            window.setFrame(preservedFrame, display: false)

            anchor.addTabbedWindow(window, ordered: .above)
            applyLockedFrame(preservedFrame, to: anchor)
            applyLockedFrame(preservedFrame, to: window)

            if pending.sceneKind == .main {
                pendingMainTabNavigations[ObjectIdentifier(window)] = PendingMainTabNavigation(
                    path: pending.path,
                    selectionPath: pending.selectionPath,
                    itemsSnapshot: pending.itemsSnapshot
                )
            }
            pendingNewTab = nil

            // 选中新建标签（列表快照已在 init 填好，切换时不应空白闪一下）。
            if let tabGroup = window.tabGroup ?? anchor.tabGroup {
                beginFrameLock(preservedFrame, windows: Array(tabGroup.windows))
                tabGroup.selectedWindow = window
            }

            applyLockedFrame(preservedFrame, to: anchor)
            applyLockedFrame(preservedFrame, to: window)
        }

        // 激活新标签；随后吞掉系统重复的 orderFront，避免激活→失焦闪动。
        isRevealingMergedTab = true
        if !window.isKeyWindow {
            window.makeKey()
        }
        isRevealingMergedTab = false

        suppressOrderFrontWindowIDs.insert(ObjectIdentifier(window))
        let mergedID = ObjectIdentifier(window)
        let newTab = window
        DispatchQueue.main.async { [weak self] in
            if newTab.tabGroup?.selectedWindow !== newTab {
                newTab.tabGroup?.selectedWindow = newTab
            }
            if !newTab.isKeyWindow {
                self?.isRevealingMergedTab = true
                newTab.makeKey()
                self?.isRevealingMergedTab = false
            }
            self?.suppressOrderFrontWindowIDs.remove(mergedID)
        }

        scheduleFrameLockRelease(after: 0.2, restoring: preservedFrame, window: newTab)
        bumpTabBarRevision()
    }

    /// 供 `NSWindow` setFrame hook 查询：合并期间强制外框不变。
    func lockedFrame(for window: NSWindow) -> NSRect? {
        guard let lock = frameLock else { return nil }
        let windowID = ObjectIdentifier(window)
        if lock.windowTokens.contains(windowID) {
            return lock.frame
        }
        if let group = window.tabGroup, lock.groupTokens.contains(ObjectIdentifier(group)) {
            return lock.frame
        }
        if let group = window.tabGroup {
            for peer in group.windows where lock.windowTokens.contains(ObjectIdentifier(peer)) {
                return lock.frame
            }
        }
        return nil
    }

    private func beginFrameLock(_ frame: NSRect, windows: [NSWindow]) {
        frameLockReleaseWorkItem?.cancel()
        var windowTokens = Set(windows.map { ObjectIdentifier($0) })
        var groupTokens = Set<ObjectIdentifier>()
        for window in windows {
            guard let group = window.tabGroup else { continue }
            groupTokens.insert(ObjectIdentifier(group))
            for peer in group.windows {
                windowTokens.insert(ObjectIdentifier(peer))
            }
        }
        if let existing = frameLock {
            windowTokens.formUnion(existing.windowTokens)
            groupTokens.formUnion(existing.groupTokens)
        }
        frameLock = (frame, windowTokens, groupTokens)
    }

    private func scheduleFrameLockRelease(after delay: TimeInterval, restoring frame: NSRect, window: NSWindow) {
        frameLockReleaseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.applyLockedFrame(frame, to: window)
            if let selected = window.tabGroup?.selectedWindow {
                self.applyLockedFrame(frame, to: selected)
            }
            self.frameLock = nil
            self.frameLockReleaseWorkItem = nil
        }
        frameLockReleaseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func applyLockedFrame(_ frame: NSRect, to window: NSWindow) {
        let previous = window.animationBehavior
        window.animationBehavior = .none
        window.setFrame(frame, display: false)
        window.animationBehavior = previous
    }

    private func scheduleHideTabBarIfSingleTab(relatedTo closingWindow: NSWindow) {
        // willClose 时 tabGroup 仍可能含即将关闭的窗，延后到下一轮再数。
        let closingID = ObjectIdentifier(closingWindow)
        DispatchQueue.main.async { [weak self] in
            self?.hideTabBarIfSingleTabRemains(excluding: closingID)
        }
    }

    private func hideTabBarIfSingleTabRemains(excluding closingID: ObjectIdentifier) {
        var seenTabGroups = Set<ObjectIdentifier>()
        for window in NSApp.windows {
            guard windowPaths[ObjectIdentifier(window)] != nil || windowSceneKinds[ObjectIdentifier(window)] != nil else {
                continue
            }
            guard window.tabbingMode != .disallowed else { continue }
            guard let tabGroup = window.tabGroup else {
                continue
            }
            let groupID = ObjectIdentifier(tabGroup)
            guard seenTabGroups.insert(groupID).inserted else { continue }

            let remaining = tabGroup.windows.filter { ObjectIdentifier($0) != closingID && !$0.isMiniaturized }
            guard remaining.count <= 1, tabGroup.isTabBarVisible else { continue }
            guard let survivor = remaining.first ?? tabGroup.windows.first else { continue }

            let preservedFrame = survivor.frame
            beginFrameLock(preservedFrame, windows: Array(tabGroup.windows))
            let previous = survivor.animationBehavior
            survivor.animationBehavior = .none
            survivor.toggleTabBar(nil)
            applyLockedFrame(preservedFrame, to: survivor)
            survivor.animationBehavior = previous
            scheduleFrameLockRelease(after: 0.15, restoring: preservedFrame, window: survivor)
            bumpTabBarRevision()
        }
    }

    /// 从当前 key 窗口打开新的独立 Explorer 窗口（⌘N / 菜单 / 工具栏）。
    func openNewWindowFromActiveExplorer() {
        let sourceWindow = NSApp.keyWindow
        let path = path(for: sourceWindow)
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        openNewWindow(path: path, from: sourceWindow)
    }

    /// 新建独立窗口（⌘N / 工具栏「新建窗口」），不合并为标签页。
    func openNewWindow(path: String, from sourceWindow: NSWindow?) {
        pendingOpen = PendingOpen(sourceWindow: sourceWindow, mode: .newWindow)
        guard let openFolderWindow = ExplorerWindowOpenBridge.shared.openFolderWindow else { return }
        openFolderWindow(ExplorerFolderWindowValue(path: path))
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
        // unifiedCompact 工具栏默认带阴影分隔，会与内容区自定义 hairline 叠加显得偏粗。
        window.titlebarSeparatorStyle = .none
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

    private func installTabDoubleClickMonitor() {
        guard tabDoubleClickMonitor == nil else { return }
        tabDoubleClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard event.clickCount == 2 else { return event }
            guard let window = event.window else { return event }
            guard ExplorerTabBarHitTesting.isTabBarClick(event, in: window) else { return event }
            guard Self.isRegisteredExplorerWindow(window) else { return event }
            window.close()
            return nil
        }
    }

    private func installTabRightClickMonitor() {
        guard tabRightClickMonitor == nil else { return }
        tabRightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            guard let window = event.window else { return event }
            guard ExplorerTabBarHitTesting.isTabBarClick(event, in: window) else { return event }

            // 切换选中会取消系统右键菜单；统一弹出对齐系统的完整菜单。
            let target = ExplorerTabBarHitTesting.activateTabUnderMouse(event: event, in: window)
            ExplorerTabBarHitTesting.popUpTabContextMenu(for: target, event: event)
            return nil
        }
    }

    private static func isRegisteredExplorerWindow(_ window: NSWindow) -> Bool {
        guard window.tabbingMode != .disallowed,
              let tabGroup = window.tabGroup,
              tabGroup.isTabBarVisible,
              tabGroup.windows.count > 1 else {
            return false
        }
        return shared.windowPaths[ObjectIdentifier(window)] != nil
            || shared.windowSceneKinds[ObjectIdentifier(window)] != nil
    }
}

/// 系统标签栏命中检测：与 unified 工具栏区域重叠，需从工具栏右键逻辑中排除。
enum ExplorerTabBarHitTesting {
    private static let tabBarMarkers = [
        "NSTabBar",
        "NSThemeTabBar",
        "NSTabButton",
        "NSThemeTabBarButton",
        "TabButton",
    ]

    static func isTabBarClick(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard window.tabbingMode != .disallowed else { return false }
        guard let tabGroup = window.tabGroup, tabGroup.isTabBarVisible, tabGroup.windows.count > 1 else {
            return false
        }

        if let hitView = hitView(at: event.locationInWindow, in: window),
           isInsideTabBar(hitView) {
            return true
        }
        return isInTabBarGeometry(event, in: window)
    }

    @discardableResult
    static func activateTabUnderMouse(event: NSEvent, in window: NSWindow) -> NSWindow {
        guard let tabGroup = window.tabGroup, tabGroup.windows.count > 1 else {
            if !window.isKeyWindow {
                window.makeKeyAndOrderFront(nil)
            }
            return window
        }

        let target = tabWindowUnderMouse(event: event, in: window) ?? window
        if tabGroup.selectedWindow !== target {
            tabGroup.selectedWindow = target
        }
        if !target.isKeyWindow {
            target.makeKeyAndOrderFront(nil)
        }
        return target
    }

    static func tabWindowUnderMouse(event: NSEvent, in window: NSWindow) -> NSWindow? {
        tabWindow(at: event, in: window)
    }

    /// 对齐系统标签栏右键菜单：
    /// 关闭标签页 / 关闭其他 / 关闭右侧 / 移到新窗口 / 显示所有标签页。
    static func popUpTabContextMenu(for window: NSWindow, event: NSEvent) {
        let target = TabBarContextMenuTarget.shared
        target.window = window

        let tabs = window.tabGroup?.windows ?? [window]
        let index = tabs.firstIndex(where: { $0 === window }) ?? 0
        let tabsToRightCount = max(0, tabs.count - index - 1)

        let menu = NSMenu()
        let closeItem = NSMenuItem(
            title: L10n.Toolbar.closeTab,
            action: #selector(TabBarContextMenuTarget.closeTab(_:)),
            keyEquivalent: ""
        )
        closeItem.target = target
        menu.addItem(closeItem)

        let closeOthersItem = NSMenuItem(
            title: L10n.Toolbar.closeOtherTabs,
            action: #selector(TabBarContextMenuTarget.closeOtherTabs(_:)),
            keyEquivalent: ""
        )
        closeOthersItem.target = target
        closeOthersItem.isEnabled = tabs.count > 1
        menu.addItem(closeOthersItem)

        let closeRightItem = NSMenuItem(
            title: L10n.Toolbar.closeTabsToTheRight,
            action: #selector(TabBarContextMenuTarget.closeTabsToTheRight(_:)),
            keyEquivalent: ""
        )
        closeRightItem.target = target
        closeRightItem.isEnabled = tabsToRightCount > 0
        menu.addItem(closeRightItem)

        let moveItem = NSMenuItem(
            title: L10n.Toolbar.moveTabToNewWindow,
            action: #selector(TabBarContextMenuTarget.moveTabToNewWindow(_:)),
            keyEquivalent: ""
        )
        moveItem.target = target
        moveItem.isEnabled = tabs.count > 1
        menu.addItem(moveItem)

        let showAllItem = NSMenuItem(
            title: L10n.Toolbar.showAllTabs,
            action: #selector(TabBarContextMenuTarget.showAllTabs(_:)),
            keyEquivalent: ""
        )
        showAllItem.target = target
        showAllItem.isEnabled = tabs.count > 1
        menu.addItem(showAllItem)

        DispatchQueue.main.async {
            guard let view = window.contentView?.superview ?? window.contentView else { return }
            let screenPoint = NSEvent.mouseLocation
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            let viewPoint = view.convert(windowPoint, from: nil)
            menu.popUp(positioning: nil, at: viewPoint, in: view)
        }
    }

    private static func tabWindow(at event: NSEvent, in window: NSWindow) -> NSWindow? {
        guard let tabGroup = window.tabGroup else { return nil }
        let tabs = tabGroup.windows
        guard tabs.count > 1 else { return nil }
        guard let index = tabButtonIndex(at: event.locationInWindow, in: window),
              tabs.indices.contains(index) else {
            return nil
        }
        return tabs[index]
    }

    private static func tabButtonIndex(at locationInWindow: NSPoint, in window: NSWindow) -> Int? {
        guard let tabBar = findTabBar(in: window) else { return nil }
        let buttons = tabButtons(in: tabBar)
            .sorted { $0.frame.minX < $1.frame.minX }
        guard !buttons.isEmpty else { return nil }

        for (index, button) in buttons.enumerated() {
            let point = button.convert(locationInWindow, from: nil)
            if button.bounds.contains(point) {
                return index
            }
        }
        return nil
    }

    private static func findTabBar(in window: NSWindow) -> NSView? {
        guard let root = window.contentView?.superview else { return nil }
        return findSubview(in: root) { view in
            let name = String(describing: type(of: view))
            return tabBarMarkers.contains(where: { name.contains($0) && !$0.contains("Button") })
                || name.contains("NSTabBar")
                || name.contains("NSThemeTabBar")
        }
    }

    private static func tabButtons(in tabBar: NSView) -> [NSView] {
        var result: [NSView] = []
        collectTabButtons(from: tabBar, into: &result)
        if !result.isEmpty { return result }

        // 退化：用可点的子视图近似标签按钮。
        return tabBar.subviews.filter { subview in
            let name = String(describing: type(of: subview))
            return name.contains("Tab") || subview is NSButton || subview.gestureRecognizers.isEmpty == false
        }
    }

    private static func collectTabButtons(from view: NSView, into result: inout [NSView]) {
        let name = String(describing: type(of: view))
        if name.contains("TabButton") || name.contains("NSTabButton") {
            result.append(view)
            return
        }
        for subview in view.subviews {
            collectTabButtons(from: subview, into: &result)
        }
    }

    private static func findSubview(in root: NSView, matching: (NSView) -> Bool) -> NSView? {
        if matching(root) { return root }
        for subview in root.subviews {
            if let found = findSubview(in: subview, matching: matching) {
                return found
            }
        }
        return nil
    }

    private static func isInsideTabBar(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let node = current {
            let name = String(describing: type(of: node))
            if tabBarMarkers.contains(where: { name.contains($0) }) {
                return true
            }
            current = node.superview
        }
        return false
    }

    private static func isInTabBarGeometry(_ event: NSEvent, in window: NSWindow) -> Bool {
        let screenLocation = NSEvent.mouseLocation
        guard window.frame.contains(screenLocation) else { return false }

        let windowPoint = NSPoint(
            x: screenLocation.x - window.frame.origin.x,
            y: screenLocation.y - window.frame.origin.y
        )
        // 标签栏紧贴 contentLayoutRect 上方；略放宽高度，覆盖上半段标签。
        let contentTop = window.contentLayoutRect.maxY
        let tabBarHeight: CGFloat = 40
        let windowTop = window.frame.height
        return windowPoint.y >= contentTop
            && windowPoint.y <= min(contentTop + tabBarHeight, windowTop)
    }

    private static func hitView(at locationInWindow: NSPoint, in window: NSWindow) -> NSView? {
        guard let root = window.contentView?.superview else { return nil }
        let point = root.convert(locationInWindow, from: nil)
        return root.hitTest(point)
    }
}

private final class TabBarContextMenuTarget: NSObject {
    static let shared = TabBarContextMenuTarget()
    weak var window: NSWindow?

    @objc func closeTab(_ sender: Any?) {
        window?.performClose(nil)
        window = nil
    }

    @objc func closeOtherTabs(_ sender: Any?) {
        guard let window, let tabGroup = window.tabGroup else { return }
        let others = tabGroup.windows.filter { $0 !== window }
        for other in others {
            other.performClose(nil)
        }
        self.window = nil
    }

    @objc func closeTabsToTheRight(_ sender: Any?) {
        guard let window, let tabGroup = window.tabGroup else { return }
        let tabs = tabGroup.windows
        guard let index = tabs.firstIndex(where: { $0 === window }) else { return }
        let toClose = Array(tabs.suffix(from: index + 1))
        for other in toClose {
            other.performClose(nil)
        }
        self.window = nil
    }

    @objc func moveTabToNewWindow(_ sender: Any?) {
        guard let window else { return }
        window.moveTabToNewWindow(nil)
        // 与 ⌘N 独立窗一致：移出后不再参与标签合并。
        window.tabbingMode = .disallowed
        window.makeKeyAndOrderFront(nil)
        self.window = nil
    }

    @objc func showAllTabs(_ sender: Any?) {
        window?.toggleTabOverview(nil)
        self.window = nil
    }
}

/// 把 TabCenter revision 观察下沉到叶子，避免 ContentView 整树随标签栏变更重绘。
struct ExplorerTabBarRevisionObserver: View {
    @ObservedObject private var center = ExplorerWindowTabCenter.shared
    let hostWindow: NSWindow?
    @Binding var state: ExplorerTabBarState

    var body: some View {
        Color.clear
            .onAppear(perform: sync)
            .onChange(of: center.tabBarRevision) { _ in
                sync()
            }
    }

    private func sync() {
        let newState = ExplorerWindowTabCenter.tabBarState(for: hostWindow)
        if state != newState {
            state = newState
        }
    }
}
