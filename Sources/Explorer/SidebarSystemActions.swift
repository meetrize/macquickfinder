import AppKit
import Foundation

/// 侧边栏条目共用的系统级操作：显示简介、打开储存空间管理。
enum SidebarSystemActions {
    /// 调起 Finder 的系统「显示简介」窗口。
    static func showInfo(forPath path: String) {
        FileOperations.showFinderInfo(atPaths: [path])
    }

    /// 打开「系统设置 ▸ 通用 ▸ 储存空间」。
    static func openStorageManagement() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.Storage",
            "x-apple.systempreferences:com.apple.preference.storage"
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}
