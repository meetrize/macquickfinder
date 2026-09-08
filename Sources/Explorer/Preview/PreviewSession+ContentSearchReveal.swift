import Foundation

extension PreviewSession {
    func revealContentSearchMatch(lineNumber: Int, query: String, matchStartUTF16: Int = 0) {
        text.searchQuery = query
        text.contentSearchJumpLine = lineNumber
        text.contentSearchJumpColumnUTF16 = max(0, matchStartUTF16)
        text.contentSearchJumpToken &+= 1
        // 同文件再次点击时 selection / 视图 identity 不变；在 session 自身发布 epoch，
        // 确保 TextFilePreview.updateNSView 一定会跑并滚到对应匹配。
        contentSearchJumpEpoch &+= 1
    }
}
