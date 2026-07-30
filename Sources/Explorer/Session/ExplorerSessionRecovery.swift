import FileList
import Foundation

/// 检测上次是否干净退出；若崩溃/强杀，下次启动回退到列表视图。
enum ExplorerSessionRecovery {
    private static var didPrepareLaunch = false
    private(set) static var didResetViewModeForUnsafeLaunch = false

    /// 在读取布局偏好之前调用。若上次未干净退出，将视图模式重置为列表。
    @discardableResult
    static func prepareLaunchIfNeeded(defaults: UserDefaults = .standard) -> Bool {
        if didPrepareLaunch {
            return didResetViewModeForUnsafeLaunch
        }
        didPrepareLaunch = true

        let previousExitedCleanly: Bool
        if defaults.object(forKey: AppPreferences.Session.exitedCleanly) == nil {
            // 首次启动：视为干净退出，保留用户偏好。
            previousExitedCleanly = true
        } else {
            previousExitedCleanly = defaults.bool(forKey: AppPreferences.Session.exitedCleanly)
        }

        // 本会话开始即标脏；正常退出时再标干净。崩溃则下次触发恢复。
        defaults.set(false, forKey: AppPreferences.Session.exitedCleanly)
        defaults.synchronize()

        guard !previousExitedCleanly else {
            didResetViewModeForUnsafeLaunch = false
            return false
        }

        resetFileListViewToDefaults(in: defaults)
        didResetViewModeForUnsafeLaunch = true
        return true
    }

    static func markCleanExit(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: AppPreferences.Session.exitedCleanly)
        defaults.synchronize()
    }

    static func resetFileListViewToDefaults(in defaults: UserDefaults) {
        defaults.set(FileListViewMode.list.rawValue, forKey: AppPreferences.FileList.viewMode)
        defaults.synchronize()
    }

    #if DEBUG
    static func resetPrepareStateForTesting() {
        didPrepareLaunch = false
        didResetViewModeForUnsafeLaunch = false
    }
    #endif
}
