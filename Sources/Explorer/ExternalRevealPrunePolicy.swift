import Foundation

/// 外部 Reveal 合并后决定哪些窗可以关掉。
///
/// 历史事故：新标签落在另一标签组时，旧逻辑把「不在 keeper 组」的全部浏览窗关掉，
/// 包括用户正在用的其它目录标签 → 表现为偶发「窗口崩溃」。
enum ExternalRevealPrunePolicy {
    enum Action: Equatable {
        case keep
        case close(reason: String)
    }

    /// 同标签组内：只清 nil 壳与本世代同目录多余窗；绝不关世代前已有业务标签。
    static func sameGroupAction(
        windowPath: String?,
        targetPath: String?,
        isAnchor: Bool,
        isNewTab: Bool,
        isPreexisting: Bool,
        isGenerationAllowed: Bool
    ) -> Action {
        if isAnchor || isNewTab { return .keep }
        let standardizedWindow = windowPath.map(ExternalSelectionPathMatcher.standardizedPath)
        if isPreexisting, standardizedWindow != nil { return .keep }
        if standardizedWindow == nil {
            return .close(reason: "same-group-nil-shell")
        }
        let standardizedTarget = targetPath.map(ExternalSelectionPathMatcher.standardizedPath)
        if isGenerationAllowed,
           let standardizedWindow,
           let standardizedTarget,
           standardizedWindow == standardizedTarget {
            return .close(reason: "surplus-allowed-same-path")
        }
        // 非目标路径新窗：宁留勿杀，避免误关用户标签。
        return .keep
    }

    /// 其它标签组 / 独立窗：只关 nil 壳与目标目录游离复本；其它已登记 path 一律保留。
    static func detachedWindowAction(
        windowPath: String?,
        targetPath: String?,
        isInAnchorGroup: Bool,
        isAnchor: Bool,
        isNewTab: Bool
    ) -> Action {
        if isAnchor || isNewTab || isInAnchorGroup { return .keep }
        let standardizedWindow = windowPath.map(ExternalSelectionPathMatcher.standardizedPath)
        if standardizedWindow == nil {
            return .close(reason: "detached-nil-shell")
        }
        let standardizedTarget = targetPath.map(ExternalSelectionPathMatcher.standardizedPath)
        if let standardizedWindow,
           let standardizedTarget,
           standardizedWindow == standardizedTarget {
            return .close(reason: "detached-same-path-duplicate")
        }
        return .keep
    }

    /// Reveal 合并刚结束后，是否应拒绝把系统壳收养成用户「+」标签。
    static func shouldRejectOrphanAdoptAfterReveal(
        secondsSinceRevealMerge: TimeInterval?,
        cooldown: TimeInterval = 1.5
    ) -> Bool {
        guard let secondsSinceRevealMerge else { return false }
        return secondsSinceRevealMerge >= 0 && secondsSinceRevealMerge < cooldown
    }
}
