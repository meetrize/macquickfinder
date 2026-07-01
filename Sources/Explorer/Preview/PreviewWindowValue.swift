import CoreGraphics
import Foundation

/// 独立预览窗口 `WindowGroup(for:)` 的参数。
struct PreviewWindowValue: Hashable, Codable, Sendable {
    let sessionID: PreviewSessionID
    /// 外部双击打开时按图片尺寸适应屏幕。
    var fitImageToScreen: Bool
    var initialWindowWidth: CGFloat?
    var initialWindowHeight: CGFloat?

    init(
        sessionID: PreviewSessionID,
        fitImageToScreen: Bool = false,
        initialWindowSize: CGSize? = nil
    ) {
        self.sessionID = sessionID
        self.fitImageToScreen = fitImageToScreen
        if let initialWindowSize, initialWindowSize.width > 0, initialWindowSize.height > 0 {
            initialWindowWidth = initialWindowSize.width
            initialWindowHeight = initialWindowSize.height
        } else {
            initialWindowWidth = nil
            initialWindowHeight = nil
        }
    }

    var initialWindowSize: CGSize? {
        guard let initialWindowWidth, let initialWindowHeight,
              initialWindowWidth > 0, initialWindowHeight > 0 else {
            return nil
        }
        return CGSize(width: initialWindowWidth, height: initialWindowHeight)
    }
}
