import Foundation

/// 文件列表行打开意图（双击、Enter、⌘↩ 等）。
public struct FileListRowOpenIntent: Equatable, Sendable {
    public let row: FileListRow
    /// ⌥ 双击或 ⌘↩ 时为 `true`。
    public let openInDetachedPreview: Bool

    public init(row: FileListRow, openInDetachedPreview: Bool = false) {
        self.row = row
        self.openInDetachedPreview = openInDetachedPreview
    }
}
