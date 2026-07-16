import Foundation

/// 在目录列举之后按需补齐 Finder 注释，避免热路径上的 MDItem/xattr。
enum FinderCommentEnricher {
    /// 批量读取注释；键为标准化路径。
    static func loadComments(for urls: [URL]) async -> [String: String] {
        guard !urls.isEmpty else { return [:] }
        return await Task.detached(priority: .utility) {
            var result: [String: String] = [:]
            result.reserveCapacity(urls.count)
            for url in urls {
                try? Task.checkCancellation()
                let comment = FileItem.finderComment(for: url)
                guard !comment.isEmpty else { continue }
                result[url.path] = comment
            }
            return result
        }.value
    }

    static func enrich(_ items: [FileItem], with commentsByPath: [String: String]) -> [FileItem] {
        guard !commentsByPath.isEmpty else { return items }
        return items.map { item in
            guard let comment = commentsByPath[item.id], comment != item.finderComment else {
                return item
            }
            return item.withFinderComment(comment)
        }
    }
}
