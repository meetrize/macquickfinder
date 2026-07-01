import Foundation

/// 输出面板底部命令行的折叠预览规则。
enum OutputCommandPreview {
    static let collapsedMaxLength = 96

    static func needsCollapse(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("\n") || trimmed.count > collapsedMaxLength
    }

    /// 单行折叠展示：换行显示为 ↵，超长末尾加省略号。
    static func collapsedLine(_ command: String) -> String {
        let flattened = command
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNewline = command.contains("\n")
        if flattened.count <= collapsedMaxLength, !hasNewline {
            return flattened
        }
        let prefix = String(flattened.prefix(collapsedMaxLength)).trimmingCharacters(in: .whitespaces)
        return prefix + "…"
    }
}
