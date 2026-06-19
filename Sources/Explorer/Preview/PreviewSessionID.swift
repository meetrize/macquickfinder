import Foundation

/// 预览会话唯一标识，用于 Session Store 与独立窗口 `WindowGroup` 传参。
struct PreviewSessionID: Hashable, Codable, Sendable, Identifiable {
    let rawValue: UUID

    var id: UUID { rawValue }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}
