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

    private init() {
        installTabDoubleClickMonitor()
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

            // 关键：新建标签留在后台，继续显示当前标签。
            // 每个标签都是完整 ContentView，切过去等于整树拆建，同目录下会像「闪一下」。
            if let tabGroup = window.tabGroup ?? anchor.tabGroup {
                beginFrameLock(preservedFrame, windows: Array(tabGroup.windows))
                tabGroup.selectedWindow = anchor
            }

            applyLockedFrame(preservedFrame, to: anchor)
            applyLockedFrame(preservedFrame, to: window)
        }

        // 吞掉系统随后对「新窗」的 orderFront，防止它抢选中态。
        suppressOrderFrontWindowIDs.insert(ObjectIdentifier(window))
        let mergedID = ObjectIdentifier(window)
        DispatchQueue.main.async { [weak self] in
            self?.suppressOrderFrontWindowIDs.remove(mergedID)
        }

        if !anchor.isKeyWindow {
            anchor.makeKey()
        }

        // AppKit 可能在合并后异步改选中标签；下一拍再钉回当前标签。
        let anchorToKeep = anchor
        DispatchQueue.main.async {
            if anchorToKeep.tabGroup?.selectedWindow !== anchorToKeep {
                anchorToKeep.tabGroup?.selectedWindow = anchorToKeep
            }
        }

        scheduleFrameLockRelease(after: 0.2, restoring: preservedFrame, window: anchor)
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
            guard Self.isRegisteredExplorerWindow(window) else { return event }
            guard Self.isMouseInTabBar(window, screenLocation: NSEvent.mouseLocation) else { return event }
            window.close()
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
    }

    /// 标签栏位于内容区正上方的一条窄带内。
    private static func isMouseInTabBar(_ window: NSWindow, screenLocation: NSPoint) -> Bool {
        guard window.frame.contains(screenLocation) else { return false }

        let windowPoint = NSPoint(
            x: screenLocation.x - window.frame.origin.x,
            y: screenLocation.y - window.frame.origin.y
        )
        let contentTop = window.contentLayoutRect.maxY
        let tabBarHeight: CGFloat = 32
        return windowPoint.y >= contentTop && windowPoint.y <= contentTop + tabBarHeight
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
