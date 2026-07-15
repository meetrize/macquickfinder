import CoreGraphics
import Foundation

struct ImageEditSnapshot: Equatable {
    var rotationQuarterTurns: Int
    var flipHorizontal: Bool
    var flipVertical: Bool
    var resizeTargetSize: CGSize?
    var zoomScale: CGFloat
    /// 已应用的剪裁（方向变换后的图像归一化坐标系，原点左上）。
    var cropRectNormalized: CGRect?
}
