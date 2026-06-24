import Foundation

/// 运行中命令的输出显示缓冲：保留尾部，避免无限输出拖垮 UI。
enum OutputRunningDisplayBuffer {
    /// 运行中 Tab 在内存里保留的 stdout 字符上限。
    static let maxCharacters = 48_000
    private static let omittedNotice = "\n…\n"

    static func trimPreservingTail(_ stdout: inout String) {
        guard stdout.count > maxCharacters else { return }
        let keep = max(0, maxCharacters - omittedNotice.count)
        stdout = omittedNotice + String(stdout.suffix(keep))
    }
}
