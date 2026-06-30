import Foundation

/// 独立预览窗口 `WindowGroup(for:)` 的参数。
struct PreviewWindowValue: Hashable, Codable, Sendable {
    let sessionID: PreviewSessionID
    /// 外部双击打开时按图片尺寸适应屏幕。
    var fitImageToScreen: Bool

    init(sessionID: PreviewSessionID, fitImageToScreen: Bool = false) {
        self.sessionID = sessionID
        self.fitImageToScreen = fitImageToScreen
    }
}
