import CoreGraphics
import Foundation

enum PreviewBrowserStripMetrics {
    static let stripHeight: CGFloat = 88
    static let navBarHeight: CGFloat = 32
    static let thumbnailSize: CGFloat = 72
    static let cellSpacing: CGFloat = 12
    static let thumbnailContentInset: CGFloat = 6
    static let cellCornerRadius: CGFloat = 6
    static let cellBorderWidth: CGFloat = 1
    static let cellSelectedBorderWidth: CGFloat = 2
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
    static let contentPrefetchSettleMilliseconds: UInt64 = 300
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
