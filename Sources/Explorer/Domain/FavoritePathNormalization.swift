import Foundation

/// 收藏路径规范化与等价比较（无 MainActor 依赖，供 Domain 与 UI 共用）。
enum FavoritePathNormalization {
    static func standardize(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    /// 解析符号链接后的规范路径，用于拖放等价判断。
    static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    static func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = canonicalPath(lhs)
        let normalizedRHS = canonicalPath(rhs)
        if normalizedLHS == normalizedRHS { return true }

        let systemVolumeRoots: Set<String> = ["/", "/System/Volumes/Data"]
        return systemVolumeRoots.contains(normalizedLHS) && systemVolumeRoots.contains(normalizedRHS)
    }

    static func isDescendant(path: String, of ancestor: String) -> Bool {
        let normalizedPath = canonicalPath(path)
        let normalizedAncestor = canonicalPath(ancestor)
        guard normalizedPath != normalizedAncestor else { return false }
        let prefix = normalizedAncestor.hasSuffix("/") ? normalizedAncestor : normalizedAncestor + "/"
        return normalizedPath.hasPrefix(prefix)
    }
}
