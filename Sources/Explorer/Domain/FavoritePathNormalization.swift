import Foundation

/// 收藏路径规范化与等价比较（无 MainActor 依赖，供 Domain 与 UI 共用）。
enum FavoritePathNormalization {
    static func standardize(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    static func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = standardize(lhs)
        let normalizedRHS = standardize(rhs)
        if normalizedLHS == normalizedRHS { return true }

        let systemVolumeRoots: Set<String> = ["/", "/System/Volumes/Data"]
        return systemVolumeRoots.contains(normalizedLHS) && systemVolumeRoots.contains(normalizedRHS)
    }
}
