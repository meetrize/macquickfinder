import Foundation

/// 预览内容加载阶段（图片 / PDF / 文本 / 媒体等）。
enum PreviewLoadPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}
