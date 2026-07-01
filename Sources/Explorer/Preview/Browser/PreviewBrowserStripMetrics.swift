import CoreGraphics
import Foundation

enum PreviewBrowserStripMetrics {
    static let stripHeight: CGFloat = 104
    /// 与 `PreviewBrowserNavBar` 的 `PanelTopBarMetrics` 行高一致（28 + 6×2）。
    static let navBarHeight: CGFloat = PanelTopBarMetrics.contentHeight + PanelTopBarMetrics.verticalPadding * 2
    static let thumbnailSize: CGFloat = 84
    static let cellSpacing: CGFloat = 14
    static let thumbnailContentInset: CGFloat = 8
    static let cellCornerRadius: CGFloat = 8
    static let cellBorderWidth: CGFloat = 1.5
    static let cellSelectedBorderWidth: CGFloat = 3
    static let thumbnailPrefetchRadius = 3

    static let centerScale: CGFloat = 1.0
    static let adjacentScale: CGFloat = 0.72
    static let distantScale: CGFloat = 0.55

    static let centerOpacity: CGFloat = 1.0
    static let adjacentOpacity: CGFloat = 0.65
    static let distantOpacity: CGFloat = 0.40

    static let scrollAnimationDuration: Double = 0.22
    static let switchDebounceMilliseconds: UInt64 = 120
    static let contentCrossfadeDuration: Double = 0.15
    /// 窗口/预览区尺寸变化后合并分辨率升级请求。
    static let imageResolutionUpgradeDebounceMilliseconds: UInt64 = 80
    /// 胶片条快速滑动时合并预取请求，避免连续触发磁盘读取。
    static let contentPrefetchSettleMilliseconds: UInt64 = 300
    /// 键盘/导航切换或当前项加载完成后立即预取相邻项。
    static let contentPrefetchImmediateDelay: UInt64 = 0
    static let contentPrefetchMaxFileSize: Int64 = 8 * 1024 * 1024
    static let contentPrefetchMaxBuffers = 2
    static let stripSpringResponse: Double = 0.28
    static let stripSpringDamping: Double = 0.82

    static func scale(forDistanceFromCenter distance: Int) -> CGFloat {
        switch abs(distance) {
        case 0: return centerScale
        case 1: return adjacentScale
        default: return distantScale
        }
    }

    static func opacity(forDistanceFromCenter distance: Int) -> CGFloat {
        switch abs(distance) {
        case 0: return centerOpacity
        case 1: return adjacentOpacity
        default: return distantOpacity
        }
    }

    static func cellSlotWidth(scale: CGFloat = centerScale) -> CGFloat {
        thumbnailSize * scale
    }
}
