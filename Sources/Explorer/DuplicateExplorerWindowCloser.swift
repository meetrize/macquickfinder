import AppKit

/// 冷启动外部 Reveal 时，SwiftUI 可能额外创建空白浏览窗/标签；保留已导航到目标目录的实例。
@MainActor
enum DuplicateExplorerWindowCloser {
    static func scheduleCoalesce(keeping request: ExternalFolderOpenCenter.OpenRequest) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            coalesce(keeping: request)
        }
    }

    private static func coalesce(keeping request: ExternalFolderOpenCenter.OpenRequest) {
        let expectedDirectory = (request.directoryPath as NSString).standardizingPath
        let browserWindows = NSApp.windows.filter(isExplorerBrowserWindow)

        guard browserWindows.count > 1 else { return }

        let keeper = preferredKeeper(
            among: browserWindows,
            expectedDirectory: expectedDirectory
        )

        for window in browserWindows where window !== keeper {
            window.close()
        }

        keeper?.makeKeyAndOrderFront(nil)
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
