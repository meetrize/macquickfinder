import AppKit

/// 外部 Reveal 时可能叠出多余标签/窗；按策略保留目标实例。
@MainActor
enum DuplicateExplorerWindowCloser {
    static func scheduleCoalesce(
        keeping request: ExternalFolderOpenCenter.OpenRequest,
        tabsOnly: Bool = false
    ) {
        // 首帧合并可能尚未 register；多拍几次盖住异步建标签。
        for delay in [0.35, 0.7, 1.2] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                coalesce(keeping: request, tabsOnly: tabsOnly)
            }
        }
    }

    /// 关掉不在 keeper 标签组内的多余浏览窗（真正的第二独立 MeoFind 窗口）。
    static func closeDetachedBrowserWindows(keepingTabGroupOf keeper: NSWindow) {
        let keeperGroup = keeper.tabGroup
        let keeperPaths = Set(
            (keeperGroup?.windows ?? [keeper]).compactMap { window -> String? in
                ExplorerWindowTabCenter.shared.path(for: window).map {
                    ExternalSelectionPathMatcher.standardizedPath($0)
                }
            }
        )
        let suppressing = ExplorerWindowTabCenter.shared.shouldIgnoreSystemNewWindowForTab

        for window in NSApp.windows {
            guard window !== keeper else { continue }
            if keeperGroup != nil, window.tabGroup === keeperGroup {
                continue
            }
            guard isExplorerBrowserWindow(window) || isRegisteredOrDetachedExplorer(window) else {
                continue
            }

            let path = ExplorerWindowTabCenter.shared.path(for: window).map {
                ExternalSelectionPathMatcher.standardizedPath($0)
            }
            let isNilShell = path == nil
            let duplicatesKeeperPath = path.map { keeperPaths.contains($0) } ?? false

            // 只关 nil 壳 + 与 keeper 组同路径的游离复本。
            // 禁止因 tabbingMode=.disallowed 关掉其它目录的已登记窗（拆组后的旧标签仍可能是用户内容）。
            guard isNilShell || duplicatesKeeperPath else {
                ExternalOpenDiagnostic.logRaw(
                    "coalesce skip detached browser path=\(path ?? "nil") suppressing=\(suppressing) disallowed=\(window.tabbingMode == .disallowed)"
                )
                continue
            }

            ExternalOpenDiagnostic.logRaw(
                "coalesce close detached browser path=\(path ?? "nil") suppressing=\(suppressing) disallowed=\(window.tabbingMode == .disallowed)"
            )
            // 走统一关窗路径，避免与 merge/selectedWindow 同步打架。
            ExplorerWindowTabCenter.shared.closeSurplusWindow(window, reason: "coalesce-detached")
        }
    }

    private static func isRegisteredOrDetachedExplorer(_ window: NSWindow) -> Bool {
        guard window.canBecomeKey else { return false }
        let kind = ExplorerWindowTabCenter.shared.sceneKind(for: window)
        if kind == .main || kind == .folder { return true }
        return ExplorerWindowTabCenter.shared.path(for: window) != nil
    }

    private static func coalesce(
        keeping request: ExternalFolderOpenCenter.OpenRequest,
        tabsOnly: Bool
    ) {
        let expectedDirectory = ExternalSelectionPathMatcher.standardizedPath(request.directoryPath)
        let browserWindows = NSApp.windows.filter(isExplorerBrowserWindow)

        guard !browserWindows.isEmpty else { return }

        // 世代内多造的窗（含 Desktop 复本）优先关掉。
        for window in ExplorerWindowTabCenter.shared.spuriousWindowsCreatedDuringProgrammaticTabGeneration() {
            ExternalOpenDiagnostic.logRaw(
                "coalesce close generation-spurious path=\(ExplorerWindowTabCenter.shared.path(for: window) ?? "nil")"
            )
            ExplorerWindowTabCenter.shared.closeSurplusWindow(window, reason: "coalesce-generation-spurious")
        }

        // 同窗口组内：不再收掉「相同目录」的多余标签（Reveal 允许同目录多标签）。
        // 只靠 generation-spurious / detached 清理壳窗。
        if !tabsOnly {
            coalesceDuplicateTabs(among: NSApp.windows.filter(isExplorerBrowserWindow), expectedDirectory: expectedDirectory)
        }

        if let keeper = ExplorerWindowTabCenter.shared.windowShowingDirectory(expectedDirectory)
            ?? preferredKeeper(among: NSApp.windows.filter(isExplorerBrowserWindow), expectedDirectory: expectedDirectory)
        {
            // 只关 nil 壳与同目录游离复本；绝不因「保留 keeper」关掉其它目录标签组。
            closeDetachedBrowserWindows(keepingTabGroupOf: keeper)
            ExplorerWindowTabCenter.shared.activateExplorerWindow(keeper)
        }

        // 历史上 tabsOnly=false 会关掉「所有非 keeper 浏览窗」，会把多标签/多窗用户内容一并拆掉。
        // 外部 Reveal 只需要 detached 清理；此处不再做整窗收束。
    }

    private static func coalesceDuplicateTabs(
        among windows: [NSWindow],
        expectedDirectory: String
    ) {
        var seenGroups = Set<ObjectIdentifier>()
        for window in windows {
            guard let tabGroup = window.tabGroup else { continue }
            let groupID = ObjectIdentifier(tabGroup)
            guard seenGroups.insert(groupID).inserted else { continue }

            let tabs = tabGroup.windows.filter(isExplorerBrowserWindow)
            guard tabs.count > 1 else { continue }

            let matching = tabs.filter { tab in
                guard let path = ExplorerWindowTabCenter.shared.path(for: tab) else {
                    return false
                }
                return ExternalSelectionPathMatcher.standardizedPath(path) == expectedDirectory
            }
            guard matching.count > 1 else { continue }

            let keeper = preferredKeeper(among: matching, expectedDirectory: expectedDirectory)
                ?? matching.first
            for tab in matching where tab !== keeper {
                ExternalOpenDiagnostic.logRaw(
                    "coalesce close duplicate tab path=\(expectedDirectory)"
                )
                ExplorerWindowTabCenter.shared.closeSurplusWindow(tab, reason: "coalesce-duplicate-tab")
            }
            if let keeper {
                ExplorerWindowTabCenter.shared.activateExplorerWindow(keeper)
            }
        }
    }

    private static func preferredKeeper(
        among windows: [NSWindow],
        expectedDirectory: String
    ) -> NSWindow? {
        let matchingDirectory = windows.filter { window in
            guard let path = ExplorerWindowTabCenter.shared.path(for: window) else {
                return false
            }
            return ExternalSelectionPathMatcher.standardizedPath(path) == expectedDirectory
        }
        if let keyMatch = matchingDirectory.first(where: { $0 == NSApp.keyWindow }) {
            return keyMatch
        }
        if let selected = matchingDirectory.first(where: { $0.tabGroup?.selectedWindow === $0 }) {
            return selected
        }
        if let firstMatch = matchingDirectory.first {
            return firstMatch
        }
        return NSApp.keyWindow ?? windows.first
    }

    private static func isExplorerBrowserWindow(_ window: NSWindow) -> Bool {
        guard window.isVisible || window.isMiniaturized, window.canBecomeKey else {
            return false
        }
        let sceneKind = ExplorerWindowTabCenter.shared.sceneKind(for: window)
        if sceneKind == .main || sceneKind == .folder {
            return true
        }
        // 含 tabbingMode=.disallowed 的独立浏览窗（曾被拆出）也要能被 coalesce 看到。
        return ExplorerWindowTabCenter.shared.path(for: window) != nil
    }
}
