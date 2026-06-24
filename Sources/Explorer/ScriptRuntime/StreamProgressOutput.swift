import Foundation

/// 让管道模式下的命令（如 `git clone`）也能在输出面板展示进度。
enum ShellCommandProgressSupport {
    private static let gitCloneRegex = try! NSRegularExpression(pattern: #"\bgit\s+clone\b"#)
    private static let quietCloneRegex = try! NSRegularExpression(
        pattern: #"\bgit\s+clone\b(?:\s+\S+)*\s+(?:--quiet|-q)\b"#
    )

    /// 为 `git clone` 自动注入 `--progress`，使非 TTY 子进程仍向 stderr 报告进度。
    static func augment(_ command: String) -> String {
        let range = NSRange(command.startIndex..., in: command)
        guard gitCloneRegex.firstMatch(in: command, range: range) != nil else { return command }
        guard quietCloneRegex.firstMatch(in: command, range: range) == nil else { return command }
        guard !command.contains("--progress") else { return command }
        guard let match = gitCloneRegex.firstMatch(in: command, range: range),
              let insertIndex = Range(match.range, in: command)?.upperBound else { return command }
        return String(command[..<insertIndex]) + " --progress" + String(command[insertIndex...])
    }
}

/// 将 `\r` 覆盖行语义转为可追加的文本流，并保留未结束的进度行。
enum StreamProgressOutput {
    struct StreamState {
        var pending = ""
    }

    /// 合并新块后返回应提交（以 `\n` 结尾）的文本；未完成行留在 `state.pending`。
    static func ingest(chunk: String, state: inout StreamState) -> String {
        let normalized = applyCarriageReturns(state.pending + chunk)
        state.pending = ""
        guard let lastNewline = normalized.lastIndex(of: "\n") else {
            state.pending = normalized
            return ""
        }
        let committed = String(normalized[...lastNewline])
        state.pending = String(normalized[normalized.index(after: lastNewline)...])
        return committed
    }

    /// 进程结束时刷出未提交的尾部。
    static func flush(state: inout StreamState) -> String {
        let tail = state.pending
        state.pending = ""
        guard !tail.isEmpty else { return "" }
        return tail + "\n"
    }

    static func applyCarriageReturns(_ text: String) -> String {
        var result = ""
        var line = ""
        for character in text {
            switch character {
            case "\r":
                line = ""
            case "\n":
                result += line + "\n"
                line = ""
            default:
                line.append(character)
            }
        }
        return result + line
    }
}
