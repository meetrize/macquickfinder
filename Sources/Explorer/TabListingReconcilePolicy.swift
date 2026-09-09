import Foundation

/// 标签切回时的列表对账策略：mtime 门闩 + 列表签名去抖。
enum TabListingReconcilePolicy {
    /// 切回 key 窗时是否需要磁盘对账。
    /// - 网络卷不信任目录 mtime，一律对账。
    /// - 本地卷：resign 快照与当前 mtime 均可用且相等 → 跳过；否则对账。
    static func shouldReconcileListingOnClaim(
        cachedMTime: Date?,
        currentMTime: Date?,
        isNetwork: Bool
    ) -> Bool {
        if isNetwork { return true }
        guard let cachedMTime, let currentMTime else { return true }
        return cachedMTime != currentMTime
    }

    /// 与 `FileListListingSignature` 同思路：按条目 id 做轻量哈希，判断列表身份是否变化。
    static func fileItemListingHash(for items: [FileItem]) -> Int {
        var hasher = Hasher()
        hasher.combine(items.count)
        for item in items {
            hasher.combine(item.id)
        }
        return hasher.finalize()
    }
}
