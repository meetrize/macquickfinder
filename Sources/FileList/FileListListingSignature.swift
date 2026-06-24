import Foundation

/// 轻量列表变更检测：O(n) 哈希，避免 `map(\.id).joined` 的大字符串分配。
enum FileListListingSignature {
    static func hash(for rows: [FileListRow]) -> Int {
        var hasher = Hasher()
        hasher.combine(rows.count)
        for row in rows {
            hasher.combine(row.id)
        }
        return hasher.finalize()
    }
}
