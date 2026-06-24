import FileList
import Foundation

/// 输出面板底部命令执行时使用的窗口快照（地址栏路径 + 列表选区）。
struct OutputExecutionContext: Equatable {
    var cwd: String
    var selectedItems: [FileItem]
    var showHiddenFiles: Bool

    var snippetContext: SnippetExecutionContext {
        SnippetExecutionContext(cwd: cwd, selectedItems: selectedItems)
    }
}

enum OutputSessionFormatting {
    /// 内联 stderr 的起止标记（私有区字符，不出现在复制文本中）。
    static let stderrOpenMarker = "\u{E000}"
    static let stderrCloseMarker = "\u{E001}"

    struct TranscriptSegment {
        var text: String
        var isStderr: Bool
    }

    static func prompt(cwd: String, command: String) -> String {
        let display = promptPath(for: cwd)
        return "\n\n\(display) $ \(command)\n"
    }

    /// 命令结束后追加到 stdout 的状态标识（单字符，一眼可辨成败）。
    static func completionStatus(exitCode: Int32) -> String {
        let marker = exitCode == 0 ? "✓" : "✗"
        return "\n\(marker)\n"
    }

    static func cancelledStatus() -> String {
        "\n⊘\n"
    }

    /// 将 stderr 块嵌入 stdout 时间线，渲染时按序插入并保持红色样式。
    static func wrapStderr(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        return "\(stderrOpenMarker)\(text)\(stderrCloseMarker)"
    }

    static func stripStderrMarkers(_ text: String) -> String {
        text
            .replacingOccurrences(of: stderrOpenMarker, with: "")
            .replacingOccurrences(of: stderrCloseMarker, with: "")
    }

    static func transcriptSegments(from stdout: String) -> [TranscriptSegment] {
        guard !stdout.isEmpty else { return [] }

        var segments: [TranscriptSegment] = []
        var remainder = stdout

        while let openRange = remainder.range(of: stderrOpenMarker) {
            let before = String(remainder[..<openRange.lowerBound])
            if !before.isEmpty {
                segments.append(TranscriptSegment(text: before, isStderr: false))
            }
            remainder = String(remainder[openRange.upperBound...])
            guard let closeRange = remainder.range(of: stderrCloseMarker) else {
                if !remainder.isEmpty {
                    segments.append(TranscriptSegment(text: remainder, isStderr: true))
                }
                return segments
            }
            let stderrText = String(remainder[..<closeRange.lowerBound])
            if !stderrText.isEmpty {
                segments.append(TranscriptSegment(text: stderrText, isStderr: true))
            }
            remainder = String(remainder[closeRange.upperBound...])
        }

        if !remainder.isEmpty {
            segments.append(TranscriptSegment(text: remainder, isStderr: false))
        }
        return segments
    }

    private static func promptPath(for cwd: String) -> String {
        let standardized = SnippetExpander.standardize(cwd)
        let name = URL(fileURLWithPath: standardized).lastPathComponent
        if name.isEmpty {
            return standardized
        }
        if standardized == "/" {
            return "/"
        }
        return name
    }
}
