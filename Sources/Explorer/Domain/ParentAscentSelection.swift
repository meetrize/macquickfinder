import Foundation

/// 升到祖先目录时，计算应在新目录列表中选中的那一层子路径。
enum ParentAscentSelection {
    /// 若 `from` 是 `to` 的真后代，返回 `to` 下通向 `from` 的直接子路径；否则 `nil`。
    static func childToSelect(from oldPath: String, to newPath: String) -> String? {
        let old = ExternalSelectionPathMatcher.standardizedPath(oldPath)
        let new = ExternalSelectionPathMatcher.standardizedPath(newPath)
        guard old != new else { return nil }

        let relative: String
        if new == "/" {
            guard old.hasPrefix("/") else { return nil }
            relative = String(old.dropFirst())
        } else {
            let prefix = new + "/"
            guard old.hasPrefix(prefix) else { return nil }
            relative = String(old.dropFirst(prefix.count))
        }

        guard !relative.isEmpty else { return nil }
        let firstComponent = relative.split(separator: "/", omittingEmptySubsequences: true).first.map(String.init)
        guard let firstComponent, !firstComponent.isEmpty else { return nil }

        if new == "/" {
            return "/" + firstComponent
        }
        return (new as NSString).appendingPathComponent(firstComponent)
    }
}
