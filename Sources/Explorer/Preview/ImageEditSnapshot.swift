import CoreGraphics
import Foundation

struct ImageEditSnapshot: Equatable {
    var rotationQuarterTurns: Int
    var flipHorizontal: Bool
    var flipVertical: Bool
    var resizeTargetSize: CGSize?
    var zoomScale: CGFloat
}
