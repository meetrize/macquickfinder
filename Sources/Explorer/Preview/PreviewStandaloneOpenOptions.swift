import CoreGraphics
import Foundation

/// 从外部或应用内快捷入口打开独立预览窗时的初始配置。
struct PreviewStandaloneOpenOptions: Equatable {
    var allowsDockBack: Bool
    var fitImageToScreen: Bool
    var initialWindowSize: CGSize?

    static let externalDefault = PreviewStandaloneOpenOptions(
        allowsDockBack: false,
        fitImageToScreen: false,
        initialWindowSize: nil
    )
}
