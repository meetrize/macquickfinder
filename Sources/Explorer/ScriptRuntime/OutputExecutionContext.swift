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
        return "\(display) $ \(command)\n"
    }

    /// 将状态图标附到最近一条尚未结束的命令行末尾（与命令同一行，制表符右对齐）。
    static func attachCompletionStatus(to stdout: inout String, exitCode: Int32) {
        let marker = exitCode == 0 ? "✓" : "✗"
        attachCompletionMarker(to: &stdout, marker: marker)
    }

    static func attachCancelledStatus(to stdout: inout String) {
        attachCompletionMarker(to: &stdout, marker: "⊘")
    }

    private static let incompletePromptPattern = #"([^\n]+) \$ ([^\n\t]+)\n"#

    private static func attachCompletionMarker(to stdout: inout String, marker: String) {
        guard let regex = try? NSRegularExpression(pattern: incompletePromptPattern) else { return }
        let ns = stdout as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: stdout, range: range)

        for match in matches.reversed() {
            guard match.numberOfRanges == 3 else { continue }
            let path = ns.substring(with: match.range(at: 1))
            let command = ns.substring(with: match.range(at: 2))
            let replacement = "\(path) $ \(command)\t\(marker)\n"
            stdout = ns.replacingCharacters(in: match.range, with: replacement)
            return
        }
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
