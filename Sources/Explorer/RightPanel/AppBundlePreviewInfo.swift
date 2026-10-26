import AppKit
import Foundation

/// `.app` 等文件包的轻量预览元数据（避免递归枚举包内文件）。
enum AppBundlePreviewInfo {
    struct Snapshot: Equatable, Sendable {
        let version: String?
        let shortVersion: String?
    }

    static func loadSnapshot(at path: String) -> Snapshot {
        let infoURL = URL(fileURLWithPath: path)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let plist = NSDictionary(contentsOf: infoURL) as? [String: Any] else {
            return Snapshot(version: nil, shortVersion: nil)
        }
        let shortVersion = stringValue(plist["CFBundleShortVersionString"])
        let version = stringValue(plist["CFBundleVersion"])
        return Snapshot(version: version, shortVersion: shortVersion)
    }

    static func workspaceIcon(at path: String, pointSize: CGFloat = 64) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: pointSize, height: pointSize)
        return icon
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
