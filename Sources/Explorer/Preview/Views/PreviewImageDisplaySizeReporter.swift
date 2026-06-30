import AppKit
import SwiftUI

/// 将图片预览内容区尺寸同步到 session，供 ImageIO 降采样预算计算。
struct PreviewImageDisplaySizeReporter: View {
    @ObservedObject var session: PreviewSession

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    session.updateImagePreviewDisplayMetrics(
                        containerSize: geometry.size,
                        screenScale: screenScale
                    )
                }
                .onChange(of: geometry.size) { newSize in
                    session.updateImagePreviewDisplayMetrics(
                        containerSize: newSize,
                        screenScale: screenScale
                    )
                }
        }
    }

    private var screenScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2.0
    }
}
