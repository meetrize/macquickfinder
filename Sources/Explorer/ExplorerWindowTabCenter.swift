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
        let activatesTab: Bool
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
    /// 程序化 openNewTab 后的短窗口：忽略系统 `newWindowForTab`，否则会叠出第二个同路径空选中标签。
    private var ignoreSystemNewWindowForTabUntil: Date?
    /// 外部 Reveal 等程序化开标签世代：只允许一个新窗，其余立即关闭。
    private var programmaticTabGeneration: ProgrammaticTabGeneration?
    /// 合并/收起标签栏期间锁定外框，阻止系统把窗口撑高造成闪动。
    private var frameLock: (frame: NSRect, windowTokens: Set<ObjectIdentifier>, groupTokens: Set<ObjectIdentifier>)?
    private var frameLockReleaseWorkItem: DispatchWorkItem?
    /// 防止 attemptTabMerge 与 interceptOrderFront 双进入 merge。
    private var isMergingNewTab = false
    /// 最近一次外部 Reveal 合并成功的新标签（同目录多标签时不能靠 path 查找，会命中旧标签）。
    private weak var lastMergedRevealWindow: NSWindow?
    @Published private(set) var tabBarRevision: UInt = 0
    private var notificationObservers: [NSObjectProtocol] = []
    private var tabDoubleClickMonitor: Any?
    private var tabRightClickMonitor: Any?

    /// 外部 odoc/Reveal 投递期间：禁止再冒出 untitled / restored 主窗。
    private var suppressSurplusRestoredWindowsUntil: Date?

    private struct ProgrammaticTabGeneration {
        let id: UUID
        weak var anchor: NSWindow?
        let targetPath: String
        let preexistingWindowIDs: Set<ObjectIdentifier>
        var allowedNewWindowIDs: Set<ObjectIdentifier>
        var expiresAt: Date
    }

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
        let standardized = ExternalSelectionPathMatcher.standardizedPath(path)
        windowPaths[id] = standardized
        windowSceneKinds[id] = sceneKind
        window.representedURL = URL(fileURLWithPath: standardized)
    }

    func path(for window: NSWindow?) -> String? {
        guard let window else { return nil }
        return windowPaths[ObjectIdentifier(window)]
    }

    func sceneKind(for window: NSWindow?) -> ExplorerWindowSceneKind {
        guard let window else { return .main }
        return windowSceneKinds[ObjectIdentifier(window)] ?? .main
    }

    /// 已注册且当前浏览目录等于 `directoryPath` 的窗口（优先：锚点同组 → 可标签 → key/选中）。
    func windowShowingDirectory(
        _ directoryPath: String,
        preferringGroupOf anchor: NSWindow? = nil
    ) -> NSWindow? {
        let target = ExternalSelectionPathMatcher.standardizedPath(directoryPath)
        let matches = NSApp.windows.filter { window in
            guard !window.isMiniaturized, window.canBecomeKey else { return false }
            let kind = sceneKind(for: window)
            guard kind == .main || kind == .folder else { return false }
            let resolved: String?
            if let registered = path(for: window) {
                resolved = registered
            } else if let urlPath = window.representedURL?.path, !urlPath.isEmpty {
                resolved = urlPath
            } else {
                resolved = nil
            }
            guard let resolved else { return false }
            return ExternalSelectionPathMatcher.standardizedPath(resolved) == target
        }
        if matches.isEmpty {
            let registeredSummary = windowPaths.map { "\($0.value)" }.sorted().joined(separator: ",")
            ExternalOpenDiagnostic.logRaw(
                "windowShowingDirectory miss target=\(target) registered=\(windowPaths.count) paths=[\(registeredSummary)]"
            )
            return nil
        }
        for window in matches where path(for: window) == nil {
            registerWindow(window, path: target, sceneKind: sceneKind(for: window))
        }

        func pickBest(in pool: [NSWindow]) -> NSWindow? {
            guard !pool.isEmpty else { return nil }
            let tabbable = pool.filter { $0.tabbingMode != .disallowed }
            let preferred = tabbable.isEmpty ? pool : tabbable
            if let key = NSApp.keyWindow, preferred.contains(where: { $0 === key }) {
                return key
            }
            if let selected = preferred.first(where: { $0.tabGroup?.selectedWindow === $0 }) {
                return selected
            }
            return preferred.min(by: { $0.orderedIndex < $1.orderedIndex })
        }

        if let anchor {
            let anchorGroup = anchor.tabGroup
            let inGroup = matches.filter { window in
                if let anchorGroup {
                    return window.tabGroup === anchorGroup
                }
                return window === anchor
            }
            if let best = pickBest(in: inGroup) {
                return best
            }
        }

        let multiTab = matches.filter {
            ($0.tabGroup?.windows.count ?? 0) > 1 && $0.tabbingMode != .disallowed
        }
        if let best = pickBest(in: multiTab) {
            return best
        }
        return pickBest(in: matches)
    }

    /// 同目录窗是否只存在于与锚点不同的标签组 / 独立窗（应改走前台新标签）。
    func isOrphanRelativeToFront(window: NSWindow, anchor: NSWindow?) -> Bool {
        if window.tabbingMode == .disallowed { return true }
        guard let anchor else { return false }
        if window === anchor { return false }
        guard let anchorGroup = anchor.tabGroup else {
            return window.tabGroup != nil
        }
        return window.tabGroup !== anchorGroup
    }

    /// 最近一次 Reveal 合并出的新标签（同目录多开时优先激活它，勿用 path 命中旧标签）。
    func lastMergedRevealTab() -> NSWindow? {
        lastMergedRevealWindow
    }

    /// 将浏览窗选为当前标签并成为 key（外部 Reveal / 同目录复用）。
    func activateExplorerWindow(_ window: NSWindow) {
        // 若曾被拆成独立窗，恢复可标签化以便回到原组选中态。
        if window.tabbingMode == .disallowed {
            window.tabbingMode = .preferred
        }
        configureExplorerWindow(window)
        if let tabGroup = window.tabGroup {
            if tabGroup.selectedWindow !== window {
                tabGroup.selectedWindow = window
            }
        }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        ExternalOpenDiagnostic.logRaw(
            "activateExplorerWindow path=\(path(for: window) ?? "nil") selected=\(window.tabGroup?.selectedWindow === window) key=\(window.isKeyWindow)"
        )
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            if let tabGroup = window.tabGroup, tabGroup.selectedWindow !== window {
                tabGroup.selectedWindow = window
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// odoc 叠出的无 path 浏览主窗：仅在外部 open 抑制期内、且确认为浏览窗时才杀。
    /// 注意：不可在全局 `orderFront` 里对任意 path=nil 窗下手——会误杀菜单/面板，导致菜单栏点不开。
    func shouldKillSurplusOdocWindow(_ window: NSWindow) -> Bool {
        if pendingNewTab != nil { return false }
        if isProgrammaticTabGenerationActive { return false }
        if path(for: window) != nil { return false }

        // 只在外部 Reveal/odoc 抑制窗内动手；平时绝不动。
        guard let until = suppressSurplusRestoredWindowsUntil, Date() < until else {
            return false
        }
        guard hasRegisteredWindows || ExternalFolderOpenCenter.shared.isSessionEstablished else {
            return false
        }

        // 排除菜单、面板、非普通层级窗。
        if window is NSPanel { return false }
        if window.level != .normal { return false }
        if window.styleMask.contains(.nonactivatingPanel) { return false }
        if !window.styleMask.contains(.titled) { return false }
        if !window.canBecomeKey { return false }

        // 未登记的 sceneKind 默认 .main，不可单独依赖；要求已是 tab 候选或挂在浏览 tabGroup。
        if window.tabbingMode == .disallowed { return false }
        if let group = window.tabGroup,
           group.windows.contains(where: { path(for: $0) != nil }) {
            return true
        }
        // 独立冒出的 titled 主窗（尚无 tabGroup）在抑制期内也可关。
        return window.tabGroup == nil
    }

    /// 关掉多余窗前先切走选中标签，减少「闪一下再关」的观感。
    func closeSurplusWindow(_ window: NSWindow, reason: String) {
        ExternalOpenDiagnostic.logRaw(
            "close surplus window reason=\(reason) path=\(path(for: window) ?? "nil")"
        )
        if let group = window.tabGroup {
            let others = group.windows.filter { $0 !== window }
            let preferred = others.first { path(for: $0) != nil } ?? others.first
            if let preferred {
                group.selectedWindow = preferred
            }
        }
        // 禁止再并进标签栏。
        window.tabbingMode = .disallowed
        window.orderOut(nil)
        DispatchQueue.main.async {
            window.close()
        }
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

    /// 当前可见的浏览窗（含尚未 register path 的壳）。
    var hasVisibleBrowserWindows: Bool {
        !visibleBrowserWindows().isEmpty
    }

    func visibleBrowserWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            guard window.isVisible || window.isMiniaturized else { return false }
            guard window.canBecomeKey else { return false }
            let kind = sceneKind(for: window)
            if kind == .main || kind == .folder { return true }
            if path(for: window) != nil { return true }
            // 尚未 register、但已挂在含已登记窗的 tabGroup 里的壳。
            if let group = window.tabGroup,
               group.windows.contains(where: { path(for: $0) != nil }) {
                return true
            }
            return false
        }
    }

    /// 外部文档/Reveal 到达前后调用：后续多余 restored 主窗一律关闭。
    func beginExternalDocumentOpenSuppression(duration: TimeInterval = 2.5) {
        let until = Date().addingTimeInterval(duration)
        suppressSurplusRestoredWindowsUntil = until
        ignoreSystemNewWindowForTabUntil = until
        ExternalOpenDiagnostic.logRaw("external-open suppression begin duration=\(duration)")
    }

    /// 已有浏览会话时，无参 main 的 restored 启动是 odoc 叠出来的第二窗，应关闭。
    func shouldRejectSurplusRestoredMainWindow() -> Bool {
        // 合法新标签走 initialPath / peekPendingNewTabNavigation，不会进 restored 分支。
        // 世代内出现的无参 restored 一律拒。
        if isProgrammaticTabGenerationActive { return true }
        // 只有「已经登记过其它浏览窗」时才拒。
        // 禁止用 hasVisibleBrowserWindows：未 register 的窗 sceneKind 默认 .main，
        // 冷启动会把自己判成已有浏览窗 → rejected-restored → close → 崩溃/闪退。
        // 禁止单靠 isSessionEstablished：ContentView 重建时窗仍在 registry，会自杀。
        return hasRegisteredWindows
    }

    /// hostWindow 挂上后二次确认：已登记的窗是 SwiftUI 重建，不是 surplus。
    func shouldCloseAsSurplusRestoredWindow(_ window: NSWindow) -> Bool {
        if path(for: window) != nil { return false }
        if windowSceneKinds[ObjectIdentifier(window)] != nil { return false }
        if isProgrammaticTabGenerationActive {
            // 世代内允许的新窗由 noteWindowAppeared / initialPath 放行；无 path 的壳可关。
            return true
        }
        // 还没有任何已登记窗时，这就是首个主窗，不能关。
        return hasRegisteredWindows
    }

    /// 调试：清空遗留 ⌘N pending，避免下一扇窗被 detach 成独立窗。
    func clearStalePendingOpen(reason: String) {
        guard pendingOpen != nil else { return }
        ExternalOpenDiagnostic.logRaw("clear stale pendingOpen reason=\(reason)")
        pendingOpen = nil
    }

    /// 程序化新建标签进行中，或刚结束后的短抑制窗：系统 `newWindowForTab` 应只关壳、勿再开一页。
    var shouldIgnoreSystemNewWindowForTab: Bool {
        if pendingNewTab != nil { return true }
        if isProgrammaticTabGenerationActive { return true }
        if let until = ignoreSystemNewWindowForTabUntil, Date() < until {
            return true
        }
        if let until = suppressSurplusRestoredWindowsUntil, Date() < until {
            return true
        }
        return false
    }

    var isProgrammaticTabGenerationActive: Bool {
        guard let generation = programmaticTabGeneration else { return false }
        return Date() < generation.expiresAt
    }

    /// 世代内出现的窗：路径命中 target / 仍有 pending 的首个新窗放行，其余关闭。
    /// - Returns: `true` 表示本窗应继续；`false` 表示已安排关闭。
    @discardableResult
    func noteWindowAppearedDuringProgrammaticTabGeneration(
        _ window: NSWindow,
        path: String? = nil
    ) -> Bool {
        guard var generation = programmaticTabGeneration, Date() < generation.expiresAt else {
            return true
        }
        let id = ObjectIdentifier(window)
        if generation.preexistingWindowIDs.contains(id) {
            return true
        }
        if generation.allowedNewWindowIDs.contains(id) {
            return true
        }

        let standardizedPath = path.map { ExternalSelectionPathMatcher.standardizedPath($0) }
        let matchesTarget = standardizedPath == generation.targetPath
        let pendingStillOpen = pendingNewTab != nil

        // 只允许「恰好一个」新窗：已有 allowed 后，即便路径命中 target 也关掉（防止 SwiftUI 双开 folder）。
        if !generation.allowedNewWindowIDs.isEmpty {
            ExternalOpenDiagnostic.logRaw(
                "tab-generation close surplus-allowed window=\(id) path=\(standardizedPath ?? "nil") target=\(generation.targetPath)"
            )
            DispatchQueue.main.async {
                window.close()
            }
            return false
        }

        if matchesTarget || pendingStillOpen {
            generation.allowedNewWindowIDs.insert(id)
            programmaticTabGeneration = generation
            ExternalOpenDiagnostic.logRaw(
                "tab-generation allow window=\(id) path=\(standardizedPath ?? "nil") target=\(generation.targetPath)"
            )
            return true
        }

        ExternalOpenDiagnostic.logRaw(
            "tab-generation close spurious window=\(id) path=\(standardizedPath ?? "nil") target=\(generation.targetPath)"
        )
        DispatchQueue.main.async {
            window.close()
        }
        return false
    }

    /// 无 pending / initialPath 的 bootstrap 若落在世代内，禁止 `restoredLaunchPath`（会造 Desktop 第三标签）。
    func shouldRejectRestoredLaunchBootstrap() -> Bool {
        isProgrammaticTabGenerationActive
    }

    func beginProgrammaticTabGeneration(from anchor: NSWindow, targetPath: String, duration: TimeInterval = 2.0) {
        // 只把「锚点」标为 preexisting。tabGroup 里未登记 / path==nil 的壳不能保护，
        // 否则 odoc 叠出来的第二窗会永远活着。
        var preexisting: Set<ObjectIdentifier> = [ObjectIdentifier(anchor)]
        if let group = anchor.tabGroup {
            for window in group.windows {
                let id = ObjectIdentifier(window)
                if id == ObjectIdentifier(anchor) { continue }
                if let registered = path(for: window), !registered.isEmpty {
                    preexisting.insert(id)
                } else {
                    ExternalOpenDiagnostic.logRaw(
                        "tab-generation drop unprotected nil-shell before begin"
                    )
                    window.close()
                }
            }
        }
        let expires = Date().addingTimeInterval(duration)
        programmaticTabGeneration = ProgrammaticTabGeneration(
            id: UUID(),
            anchor: anchor,
            targetPath: ExternalSelectionPathMatcher.standardizedPath(targetPath),
            preexistingWindowIDs: preexisting,
            allowedNewWindowIDs: [],
            expiresAt: expires
        )
        ignoreSystemNewWindowForTabUntil = expires
        let pathList = (anchor.tabGroup?.windows ?? [anchor]).map { path(for: $0) ?? "nil" }.joined(separator: ", ")
        ExternalOpenDiagnostic.logRaw(
            "tab-generation begin target=\(targetPath) preexisting=\(preexisting.count) paths=[\(pathList)]"
        )
    }

    func extendProgrammaticTabGeneration(by duration: TimeInterval = 1.5) {
        guard var generation = programmaticTabGeneration else { return }
        generation.expiresAt = Date().addingTimeInterval(duration)
        programmaticTabGeneration = generation
        ignoreSystemNewWindowForTabUntil = generation.expiresAt
    }

    func endProgrammaticTabGeneration() {
        programmaticTabGeneration = nil
        ExternalOpenDiagnostic.logRaw("tab-generation end")
    }

    /// 世代内创建、且不是唯一合法新标签的窗（供 coalesce 兜底）。
    func spuriousWindowsCreatedDuringProgrammaticTabGeneration() -> [NSWindow] {
        guard let generation = programmaticTabGeneration, Date() < generation.expiresAt else {
            return []
        }
        return NSApp.windows.filter { window in
            let id = ObjectIdentifier(window)
            guard !generation.preexistingWindowIDs.contains(id) else { return false }
            guard window.tabbingMode != .disallowed else { return false }
            let kind = sceneKind(for: window)
            guard kind == .main || kind == .folder else { return false }
            return !generation.allowedNewWindowIDs.contains(id)
        }
    }

    /// Reveal 合并后：关掉世代外冒出的窗，以及与锚点同路径的多余复本（untitled→Desktop）。
    func pruneDuplicateAnchorTabsForReveal(anchor: NSWindow, newTab: NSWindow) {
        pruneTabGroupAfterExternalReveal(anchor: anchor, newTab: newTab)
        activateExplorerWindow(newTab)
    }

    private func pruneTabGroupAfterExternalReveal(anchor: NSWindow, newTab: NSWindow) {
        guard let group = newTab.tabGroup ?? anchor.tabGroup else { return }
        let anchorID = ObjectIdentifier(anchor)
        let newID = ObjectIdentifier(newTab)
        let generation = programmaticTabGeneration
        let targetPath = generation?.targetPath
        let keeperGroup = group

        for window in Array(group.windows) {
            let id = ObjectIdentifier(window)
            if id == anchorID || id == newID { continue }
            if let generation, generation.allowedNewWindowIDs.contains(id), id != newID {
                // 世代内只允许一个新窗；其余即便曾 allow 也关掉。
                ExternalOpenDiagnostic.logRaw(
                    "tab-generation prune surplus-allowed path=\(path(for: window) ?? "nil")"
                )
                window.close()
                continue
            }

            let windowPath = path(for: window).map { ExternalSelectionPathMatcher.standardizedPath($0) }
            let isPreexisting = generation?.preexistingWindowIDs.contains(id) == true

            // 业务标签（世代前已有且 path 非空）保留；nil 壳与本世代垃圾关掉。
            if isPreexisting, windowPath != nil { continue }

            ExternalOpenDiagnostic.logRaw(
                "tab-generation prune newcomer path=\(windowPath ?? "nil") target=\(targetPath ?? "nil")"
            )
            window.close()
        }

        // 关掉不在 keeper 标签组内的游离浏览窗（真正的「第二个 MeoFind 窗口」）。
        for window in NSApp.windows {
            guard window !== anchor, window !== newTab else { continue }
            guard window.canBecomeKey else { continue }
            let kind = sceneKind(for: window)
            guard kind == .main || kind == .folder || windowPaths[ObjectIdentifier(window)] != nil else {
                continue
            }
            if window.tabGroup === keeperGroup { continue }
            ExternalOpenDiagnostic.logRaw(
                "tab-generation prune detached-window path=\(path(for: window) ?? "nil")"
            )
            window.close()
        }
    }

    private func beginIgnoreSystemNewWindowForTab(for duration: TimeInterval = 1.0) {
        ignoreSystemNewWindowForTabUntil = Date().addingTimeInterval(duration)
    }

    /// 外部 Reveal：用 folder WindowValue 带 path+selection 开窗，再合并进锚点标签组。
    /// 同目录也允许再开一页（每次 Reveal = 新标签 + 选中）。
    func openExternalRevealTab(
        path: String,
        selectionPath: String?,
        from sourceWindow: NSWindow?,
        activatesTab: Bool = true
    ) {
        let anchor = sourceWindow ?? NSApp.keyWindow
        guard let anchor else {
            ExternalOpenDiagnostic.logRaw("openExternalRevealTab failed — no anchor")
            return
        }

        ExternalOpenDiagnostic.logRaw(
            "openExternalRevealTab begin path=\(path) selection=\(selectionPath ?? "nil") anchor=\(self.path(for: anchor) ?? "nil")"
        )

        // 先开世代/抑制，再 configure/activate，避免 orderFront 触发系统在门闩前再抛壳。
        if pendingNewTab != nil {
            ExternalOpenDiagnostic.logRaw(
                "openExternalRevealTab ignored — pending already in flight path=\(pendingNewTab?.path ?? "?")"
            )
            return
        }

        beginExternalDocumentOpenSuppression(duration: 2.5)
        beginProgrammaticTabGeneration(from: anchor, targetPath: path)

        configureExplorerWindow(anchor)

        // 关键：清掉遗留的 ⌘N pendingOpen，否则 handleExplorerWindowDidAppear
        // 会把 Reveal 新标签 removeWindow + tabbingMode=.disallowed 拆成独立窗。
        if pendingOpen != nil {
            ExternalOpenDiagnostic.logRaw("openExternalRevealTab clear stale pendingOpen(.newWindow)")
            pendingOpen = nil
        }

        pendingNewTab = PendingNewTab(
            sourceWindow: anchor,
            sceneKind: sceneKind(for: anchor),
            path: path,
            selectionPath: selectionPath,
            itemsSnapshot: nil,
            activatesTab: activatesTab
        )

        guard let openFolderWindow = ExplorerWindowOpenBridge.shared.openFolderWindow else {
            ExternalOpenDiagnostic.logRaw("openExternalRevealTab failed — no openFolderWindow bridge")
            pendingNewTab = nil
            endProgrammaticTabGeneration()
            return
        }

        ExternalOpenDiagnostic.logRaw(
            "openExternalRevealTab folder-value path=\(path) selection=\(selectionPath ?? "nil")"
        )
        openFolderWindow(
            ExplorerFolderWindowValue(path: path, selectionPath: selectionPath)
        )
    }

    /// 在当前窗口组中新建标签页（工具栏 / ⌘T / 系统标签栏「+」：同场景、同路径、直接合并）。
    /// - Parameter activatesTab: 外部 Reveal 等场景为 true，合并后强制选中并激活新标签。
    func openNewTab(
        path: String,
        selectionPath: String? = nil,
        itemsSnapshot: [FileItem]? = nil,
        from sourceWindow: NSWindow?,
        activatesTab: Bool = true
    ) {
        let anchor = sourceWindow ?? NSApp.keyWindow
        guard let anchor else { return }

        configureExplorerWindow(anchor)

        let sceneKind = sceneKind(for: anchor)
        // 已有进行中的新建：绝不能覆盖 pending（否则会丢掉 selectionPath）或再开第二窗。
        if pendingNewTab != nil {
            ExternalOpenDiagnostic.logRaw(
                "openNewTab ignored — pending already in flight path=\(pendingNewTab?.path ?? "?")"
            )
            return
        }

        beginIgnoreSystemNewWindowForTab()
        // 工具栏 ⌘T 也开世代，防止系统壳叠页。
        beginProgrammaticTabGeneration(from: anchor, targetPath: path, duration: 1.2)

        pendingNewTab = PendingNewTab(
            sourceWindow: anchor,
            sceneKind: sceneKind,
            path: path,
            selectionPath: selectionPath,
            itemsSnapshot: itemsSnapshot,
            activatesTab: activatesTab
        )

        switch sceneKind {
        case .main:
            ExternalOpenDiagnostic.logRaw("openNewTab openMainWindow path=\(path)")
            ExplorerWindowOpenBridge.shared.openMainWindow?()
        case .folder:
            guard let openFolderWindow = ExplorerWindowOpenBridge.shared.openFolderWindow else {
                pendingNewTab = nil
                endProgrammaticTabGeneration()
                return
            }
            ExternalOpenDiagnostic.logRaw("openNewTab openFolderWindow path=\(path)")
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

        // 注意：不要在全局 orderFront 里 close 窗。菜单/面板也会走 makeKeyAndOrderFront，
        // 误杀会导致菜单栏完全点不开。odoc 壳只在 attemptTabMerge / rejected-restored 里关。

        guard let pending = pendingNewTab else { return false }
        guard pending.sourceWindow !== window else { return false }
        guard let anchor = pending.sourceWindow else { return false }
        guard window.tabbingMode != .disallowed else { return false }
        _ = noteWindowAppearedDuringProgrammaticTabGeneration(window, path: pending.path)
        mergeNewTabWindow(window, into: anchor, pending: pending)
        return true
    }

    /// 在 `NSWindow` 挂到视图层级时尽早合并，避免独立窗口闪现。
    /// - Returns: `false` 表示本窗已作为 surplus 关闭，调用方勿再 configure/merge。
    @discardableResult
    func attemptTabMerge(for window: NSWindow) -> Bool {
        if shouldKillSurplusOdocWindow(window) {
            closeSurplusWindow(window, reason: "attemptTabMerge-odoc")
            return false
        }
        _ = noteWindowAppearedDuringProgrammaticTabGeneration(
            window,
            path: path(for: window) ?? pendingNewTab?.path
        )
        guard let pending = pendingNewTab else { return true }
        guard pending.sourceWindow !== window else { return true }
        guard let anchor = pending.sourceWindow else {
            pendingNewTab = nil
            return true
        }
        mergeNewTabWindow(window, into: anchor, pending: pending)
        return true
    }

    private func mergeNewTabWindow(_ window: NSWindow, into anchor: NSWindow, pending: PendingNewTab) {
        // 先清空 pending，避免 attemptTabMerge + orderFront 拦截双进 merge。
        guard !isMergingNewTab else {
            ExternalOpenDiagnostic.logRaw("mergeNewTabWindow skipped — already merging")
            return
        }
        isMergingNewTab = true
        defer { isMergingNewTab = false }
        if pendingNewTab != nil {
            pendingNewTab = nil
        }

        configureExplorerWindow(window)
        configureExplorerWindow(anchor)
        // 合并进标签组后必须保持可 tab；禁止随后被当成独立窗。
        window.tabbingMode = .preferred
        anchor.tabbingMode = .preferred

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

            pendingMainTabNavigations[ObjectIdentifier(window)] = PendingMainTabNavigation(
                path: pending.path,
                selectionPath: pending.selectionPath,
                itemsSnapshot: pending.itemsSnapshot
            )

            // 选中新建标签（列表快照已在 init 填好，切换时不应空白闪一下）。
            if let tabGroup = window.tabGroup ?? anchor.tabGroup {
                beginFrameLock(preservedFrame, windows: Array(tabGroup.windows))
                tabGroup.selectedWindow = window
            }

            applyLockedFrame(preservedFrame, to: anchor)
            applyLockedFrame(preservedFrame, to: window)
        }

        // 尽早登记 path，避免后续 Reveal 因 path==nil 误判「无同目录标签」。
        registerWindow(window, path: pending.path, sceneKind: .folder)
        lastMergedRevealWindow = window
        _ = noteWindowAppearedDuringProgrammaticTabGeneration(window, path: pending.path)
        extendProgrammaticTabGeneration(by: 1.5)
        ExternalOpenDiagnostic.logRaw(
            "tab-generation merged path=\(pending.path) selection=\(pending.selectionPath ?? "nil") win=\(String(ObjectIdentifier(window).hashValue, radix: 16))"
        )
        // 外部 Reveal：合并后只保留「世代前已有窗 + 唯一新标签」，并去掉与锚点同路径的复本。
        if pending.activatesTab {
            pruneTabGroupAfterExternalReveal(anchor: anchor, newTab: window)
        }

        let shouldActivate = pending.activatesTab
        isRevealingMergedTab = true
        if shouldActivate {
            NSApp.activate(ignoringOtherApps: true)
            if let tabGroup = window.tabGroup ?? anchor.tabGroup {
                tabGroup.selectedWindow = window
            }
            window.makeKeyAndOrderFront(nil)
        } else if !window.isKeyWindow {
            window.makeKey()
        }
        isRevealingMergedTab = false

        // 外部 Reveal 需要稳定前台：不要吞掉后续 orderFront。
        // 内部 ⌘T 仍短暂 suppress，减轻激活→失焦闪动。
        let mergedID = ObjectIdentifier(window)
        let newTab = window
        if !shouldActivate {
            suppressOrderFrontWindowIDs.insert(mergedID)
        }
        beginIgnoreSystemNewWindowForTab(for: 1.0)

        let activationDelays: [TimeInterval] = shouldActivate ? [0.0, 0.05, 0.2, 0.45] : [0.0]
        for delay in activationDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                if newTab.tabGroup?.selectedWindow !== newTab {
                    newTab.tabGroup?.selectedWindow = newTab
                }
                if shouldActivate {
                    NSApp.activate(ignoringOtherApps: true)
                    self.isRevealingMergedTab = true
                    newTab.makeKeyAndOrderFront(nil)
                    self.isRevealingMergedTab = false
                } else if !newTab.isKeyWindow {
                    self.isRevealingMergedTab = true
                    newTab.makeKey()
                    self.isRevealingMergedTab = false
                }
                if delay >= 0.2 {
                    self.suppressOrderFrontWindowIDs.remove(mergedID)
                }
            }
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

        // Reveal / 程序化新标签合并期间绝不走 ⌘N 拆窗逻辑。
        if pendingNewTab != nil || isProgrammaticTabGenerationActive || isMergingNewTab {
            bumpTabBarRevision()
            return
        }

        guard let pendingOpen else {
            bumpTabBarRevision()
            return
        }

        guard pendingOpen.sourceWindow !== window else {
            return
        }

        guard pendingOpen.mode == .newWindow else { return }

        self.pendingOpen = nil
        ExternalOpenDiagnostic.logRaw("handleExplorerWindowDidAppear detach for ⌘N new window")
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
