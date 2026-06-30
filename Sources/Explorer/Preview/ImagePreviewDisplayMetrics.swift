import CoreGraphics
import Foundation

/// 根据预览容器尺寸估算 ImageIO 降采样预算（点 × scale × 余量，带上限）。
enum ImagePreviewDisplayMetrics {
    /// 全分辨率升级前的绝对上限（与旧版固定 4096 对齐）。
    static let absoluteMaxPixelBudget = 4096
    /// 极小面板仍保证最低解码清晰度。
    static let minimumPixelBudget = 256
    /// 允许适度放大（约 150%）而不立即触发全分辨率重载。
    static let decodeHeadroom: CGFloat = 1.5

    static func pixelBudget(containerSize: CGSize, screenScale: CGFloat) -> Int {
        guard containerSize.width > 0, containerSize.height > 0 else {
            return absoluteMaxPixelBudget
        }
        let longestEdgePoints = max(containerSize.width, containerSize.height)
        let raw = longestEdgePoints * max(screenScale, 1) * decodeHeadroom
        let clamped = Int(raw.rounded())
        return min(absoluteMaxPixelBudget, max(minimumPixelBudget, clamped))
    }
}
