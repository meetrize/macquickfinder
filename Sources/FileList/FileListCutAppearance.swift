import AppKit
import Foundation

/// 剪切态视觉：对齐 Finder，图标与文件名半透明「幽灵」效果。
public enum FileListCutAppearance {
    /// Finder 剪切项约半透明；选中高亮仍由 row/overlay 全不透明绘制。
    public static let contentAlpha: CGFloat = 0.45

    public static func alpha(isCut: Bool) -> CGFloat {
        isCut ? contentAlpha : 1
    }

    public static func isCutItem(id itemID: String, cutItemIDs: Set<String>) -> Bool {
        guard !cutItemIDs.isEmpty, !itemID.isEmpty else { return false }
        if cutItemIDs.contains(itemID) { return true }
        let standardized = URL(fileURLWithPath: itemID).standardizedFileURL.path
        return cutItemIDs.contains(standardized)
    }

    public static func pathSet(from urls: [URL]) -> Set<String> {
        var paths = Set<String>()
        paths.reserveCapacity(urls.count * 2)
        for url in urls {
            paths.insert(url.path)
            paths.insert(url.standardizedFileURL.path)
        }
        return paths
    }
}
