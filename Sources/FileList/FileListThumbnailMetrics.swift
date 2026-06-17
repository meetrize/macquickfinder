import CoreGraphics
import Foundation

/// 缩略图网格布局常量。
public enum FileListThumbnailMetrics {
    public static let minCellSize: CGFloat = 64
    public static let maxCellSize: CGFloat = 256
    public static let defaultCellSize: CGFloat = 128
    public static let cellSizeStep: CGFloat = 8
    public static let cellSpacing: CGFloat = 4
    public static let contentInset: CGFloat = 8
    public static let labelOverlayHeight: CGFloat = 20
    public static let sizeBadgeCornerRadius: CGFloat = 4
    public static let iconContentInsetRatio: CGFloat = 0.12
    public static let selectionBorderWidth: CGFloat = 2
    public static let cellCornerRadius: CGFloat = 4
    
    public static func clamp(cellSize: CGFloat) -> CGFloat {
        min(max(cellSize, minCellSize), maxCellSize)
    }
    
    public static func steppedCellSize(from value: CGFloat) -> CGFloat {
        let clamped = clamp(cellSize: value)
        let steps = round((clamped - minCellSize) / cellSizeStep)
        return minCellSize + steps * cellSizeStep
    }
    
    public static func thumbnailSizeBucket(for cellSize: CGFloat) -> Int {
        Int(steppedCellSize(from: cellSize) / cellSizeStep) * Int(cellSizeStep)
    }
    
    /// 在容器内保持比例放大图片：宽、高至少一边贴满容器，另一边居中，超出部分由调用方裁剪。
    public static func aspectFillFrame(imageSize: NSSize, in containerSize: NSSize) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0
        else {
            return NSRect(origin: .zero, size: containerSize)
        }
        
        let scale = max(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let displaySize = NSSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        return NSRect(
            x: (containerSize.width - displaySize.width) / 2,
            y: (containerSize.height - displaySize.height) / 2,
            width: displaySize.width,
            height: displaySize.height
        )
    }
}
