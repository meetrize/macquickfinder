import CoreGraphics
import Foundation

/// 输出面板底部命令行的折叠预览规则。
enum OutputCommandPreview {
    static let collapsedMaxLength = 96
    static let lineHeight: CGFloat = 17
    static let editorVerticalInset: CGFloat = 16
    static let minimumVisibleLines = 4
    static let maximumVisibleLines = 14

    /// 展开多行编辑器时，除编辑器内容外底部栏占用的固定高度（divider、内边距、执行按钮行等）。
    static let expandedBottomChromeHeight: CGFloat = 55
    /// 补全提示单行估算高度（caption + 上内边距）。
    static let completionHintLineHeight: CGFloat = 18
    static let minimumExpandedEditorHeight: CGFloat = 44

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

    /// 内联展开时的理想编辑器高度（按行数估算，带上限）。
    static func expandedEditorHeight(for command: String) -> CGFloat {
        let lineCount = max(command.components(separatedBy: .newlines).count, 1)
        let clampedLines = min(max(lineCount, minimumVisibleLines), maximumVisibleLines)
        return CGFloat(clampedLines) * lineHeight + editorVerticalInset
    }

    /// 当前输出面板高度下，多行编辑器允许的最大高度。
    static func maxExpandedEditorHeight(
        panelHeight: CGFloat,
        hasCompletionHint: Bool,
        completionHintLineCount: Int = 3
    ) -> CGFloat {
        let hintAllowance: CGFloat = hasCompletionHint
            ? 4 + CGFloat(min(max(completionHintLineCount, 1), 3)) * completionHintLineHeight
            : 0
        let reserved = OutputPanelMetrics.titleBarHeight + expandedBottomChromeHeight + hintAllowance
        return max(minimumExpandedEditorHeight, panelHeight - reserved)
    }

    /// 给定编辑器高度时，输出面板至少需要的高度。
    static func minimumPanelHeight(
        forExpandedEditorHeight editorHeight: CGFloat,
        hasCompletionHint: Bool,
        completionHintLineCount: Int = 3
    ) -> CGFloat {
        let hintAllowance: CGFloat = hasCompletionHint
            ? 4 + CGFloat(min(max(completionHintLineCount, 1), 3)) * completionHintLineHeight
            : 0
        return OutputPanelMetrics.titleBarHeight
            + expandedBottomChromeHeight
            + hintAllowance
            + max(editorHeight, minimumExpandedEditorHeight)
    }

    /// 结合理想高度与面板可用空间，得到最终编辑器高度。
    static func resolvedExpandedEditorHeight(
        for command: String,
        panelHeight: CGFloat,
        hasCompletionHint: Bool,
        completionHintLineCount: Int = 3
    ) -> CGFloat {
        let preferred = expandedEditorHeight(for: command)
        let maxAllowed = maxExpandedEditorHeight(
            panelHeight: panelHeight,
            hasCompletionHint: hasCompletionHint,
            completionHintLineCount: completionHintLineCount
        )
        return min(preferred, maxAllowed)
    }
}
