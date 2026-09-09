import AppKit
import Foundation

/// 在系统 Finder（`com.apple.finder`）中打开路径，避免走「默认文件查看器」（可能是本应用）。
enum FinderHelper {
    static func reveal(at path: String) {
        let standardizedPath = (path as NSString).standardizingPath
        guard FileManager.default.fileExists(atPath: standardizedPath) else { return }

        let finderURL =
            NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: DefaultFileViewerManager.finderBundleIdentifier
            )
            ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: standardizedPath)],
            withApplicationAt: finderURL,
            configuration: configuration
        )
    }
}
