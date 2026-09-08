import AppKit

/// 冷启动外部 Reveal 时，SwiftUI / 温启动误判可能额外创建浏览窗或同路径标签；保留一个目标实例。
@MainActor
enum DuplicateExplorerWindowCloser {
    static func scheduleCoalesce(keeping request: ExternalFolderOpenCenter.OpenRequest) {
        // 首帧合并可能尚未 register；多拍几次盖住异步建标签。
        for delay in [0.35, 0.7, 1.2] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                coalesce(keeping: request)
            }
        }
    }

    private static func coalesce(keeping request: ExternalFolderOpenCenter.OpenRequest) {
        let expectedDirectory = (request.directoryPath as NSString).standardizingPath
        let browserWindows = NSApp.windows.filter(isExplorerBrowserWindow)

        guard !browserWindows.isEmpty else { return }

        // 先按窗口组收掉同路径的多余标签，再收多余独立窗。
        coalesceDuplicateTabs(among: browserWindows, expectedDirectory: expectedDirectory)

        let remaining = NSApp.windows.filter(isExplorerBrowserWindow)
        guard remaining.count > 1 else { return }

        let keeper = preferredKeeper(
            among: remaining,
            expectedDirectory: expectedDirectory
        )

        for window in remaining where window !== keeper {
            window.close()
        }

        keeper?.makeKeyAndOrderFront(nil)
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
                return (path as NSString).standardizingPath == expectedDirectory
            }
            // 仅当至少两个标签都已落到目标目录时收掉多余的，避免误关仍在加载的壳。
            guard matching.count > 1 else { continue }

            let keeper = preferredKeeper(among: matching, expectedDirectory: expectedDirectory)
                ?? matching.first
            for tab in matching where tab !== keeper {
                tab.close()
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
            return (path as NSString).standardizingPath == expectedDirectory
        }
        if let keyMatch = matchingDirectory.first(where: { $0 == NSApp.keyWindow }) {
            return keyMatch
        }
        if let firstMatch = matchingDirectory.first {
            return firstMatch
        }
        return NSApp.keyWindow ?? windows.first
    }

    private static func isExplorerBrowserWindow(_ window: NSWindow) -> Bool {
        guard window.isVisible, !window.isMiniaturized, window.canBecomeKey else {
            return false
        }
        guard window.tabbingMode != .disallowed else { return false }
        let sceneKind = ExplorerWindowTabCenter.shared.sceneKind(for: window)
        return sceneKind == .main || sceneKind == .folder
    }
}
