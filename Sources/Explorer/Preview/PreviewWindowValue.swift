import Foundation

/// 独立预览窗口 `WindowGroup(for:)` 的参数。
struct PreviewWindowValue: Hashable, Codable, Sendable {
    let sessionID: PreviewSessionID
}
