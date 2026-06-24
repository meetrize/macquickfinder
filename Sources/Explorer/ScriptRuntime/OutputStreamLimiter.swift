import Foundation

enum OutputStreamLimiter {
    /// 单 Job stdout + stderr 合计字符上限（约 1.5MB，按字符计）。
    static let maxCharactersPerJob = 1_500_000

    /// 追加输出；若超出上限则截断并写入一次性提示到 stderr。
    @discardableResult
    static func append(
        stdout: inout String,
        stderr: inout String,
        truncated: inout Bool,
        stdoutChunk: String?,
        stderrChunk: String?,
        truncationNotice: String
    ) -> Bool {
        guard !truncated else { return false }

        let noticeLength = truncationNotice.count + 1

        if let stdoutChunk, !stdoutChunk.isEmpty {
            switch appendChunk(
                stdoutChunk,
                to: &stdout,
                stdout: stdout,
                stderr: stderr,
                noticeReserve: noticeLength
            ) {
            case .appended:
                break
            case .truncated, .noRoom:
                truncated = true
                appendNotice(truncationNotice, to: &stderr, noticeLength: noticeLength)
                return false
            }
        }

        if let stderrChunk, !stderrChunk.isEmpty {
            switch appendChunk(
                stderrChunk,
                to: &stderr,
                stdout: stdout,
                stderr: stderr,
                noticeReserve: noticeLength
            ) {
            case .appended:
                return true
            case .truncated, .noRoom:
                truncated = true
                appendNotice(truncationNotice, to: &stderr, noticeLength: noticeLength)
                return false
            }
        }

        return true
    }

    private enum AppendResult {
        case appended
        case truncated
        case noRoom
    }

    private static func remaining(stdout: String, stderr: String, noticeReserve: Int = 0) -> Int {
        max(0, maxCharactersPerJob - stdout.count - stderr.count - noticeReserve)
    }

    private static func appendChunk(
        _ chunk: String,
        to stream: inout String,
        stdout: String,
        stderr: String,
        noticeReserve: Int
    ) -> AppendResult {
        let budget = remaining(stdout: stdout, stderr: stderr, noticeReserve: noticeReserve)
        guard budget > 0 else { return .noRoom }
        if chunk.count <= budget {
            stream += chunk
            return .appended
        }
        stream += String(chunk.prefix(budget))
        return .truncated
    }

    private static func appendNotice(_ notice: String, to stderr: inout String, noticeLength: Int) {
        let message = notice + "\n"
        precondition(message.count <= noticeLength)
        stderr += message
    }
}
