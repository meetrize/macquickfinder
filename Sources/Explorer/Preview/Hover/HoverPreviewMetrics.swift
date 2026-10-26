import CoreGraphics
import Foundation

/// 悬停预览性能与尺寸阈值（设计红线，勿在调用处散落魔法数）。
enum HoverPreviewMetrics {
    /// 鼠标停稳后再加载，避免扫过目录狂 IO。
    static let showDelay: TimeInterval = 0.18
    /// 解码最长边（与更大面板匹配，约 2x 下仍可控）。
    static let maxPixelEdge: Int = 1280
    /// 超过此体积的图片改走 QL 缩略，避免全量解码。
    static let maxSourceBytesForFullDecode: Int64 = 25 * 1024 * 1024
    /// 文本只读头。
    static let textPreviewMaxBytes = 16_384
    /// 进程级 LRU 缓存字节预算。
    static let cacheBudgetBytes = 48 * 1024 * 1024
    static let cacheMaxEntries = 24
    static let loadTimeout: TimeInterval = 2.0
    /// 默认 / 最大面板尺寸（逻辑点）。
    static let panelMaxWidth: CGFloat = 720
    static let panelMaxHeight: CGFloat = 540
    static let panelMinWidth: CGFloat = 360
    static let panelMinHeight: CGFloat = 280
    static let panelDefaultWidth: CGFloat = 640
    static let panelDefaultHeight: CGFloat = 480
    static let screenInset: CGFloat = 8
    /// 相对光标的偏移，避免挡住指针。
    static let cursorOffsetX: CGFloat = 18
    static let cursorOffsetY: CGFloat = -16
}
