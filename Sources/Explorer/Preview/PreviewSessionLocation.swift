import Foundation

/// 预览会话在 UI 中的挂载位置。
enum PreviewSessionLocation: Equatable, Sendable {
    case inline
    case detached(windowNumber: Int?)

    var isDetached: Bool {
        if case .detached = self { return true }
        return false
    }
}
