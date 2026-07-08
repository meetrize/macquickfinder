import AppKit
import Foundation

/// Mermaid 图在预览区内的显示尺寸：在不超过视口宽高的前提下尽量放大（等比缩放）。
enum MarkdownPreviewMermaidFitting {
    struct Viewport: Equatable {
        let maxWidth: CGFloat
        let maxHeight: CGFloat

        func isApproximatelyEqual(to other: Viewport, tolerance: CGFloat = 0.5) -> Bool {
            abs(maxWidth - other.maxWidth) <= tolerance
                && abs(maxHeight - other.maxHeight) <= tolerance
        }
    }

    /// 将自然尺寸等比缩放至 `maxWidth` × `maxHeight` 内；小图会放大填满可用空间。
    static func displaySize(naturalSize: NSSize, viewport: Viewport) -> NSSize {
        let maxWidth = max(viewport.maxWidth, 1)
        let maxHeight = max(viewport.maxHeight, 1)
        guard naturalSize.width > 0, naturalSize.height > 0 else {
            return NSSize(width: maxWidth, height: max(maxHeight * 0.25, 32))
        }

        let widthScale = maxWidth / naturalSize.width
        let heightScale = maxHeight / naturalSize.height
        let scale = min(widthScale, heightScale)

        return NSSize(
            width: max(ceil(naturalSize.width * scale), 1),
            height: max(ceil(naturalSize.height * scale), 1)
        )
    }

    /// 根据滚动视图可见区域与屏幕尺寸推导逻辑坐标下的最大宽高（已考虑预览缩放）。
    static func viewport(
        scrollView: NSScrollView,
        zoomScale: CGFloat,
        textContentInset: CGFloat
    ) -> Viewport {
        let normalizedScale = max(zoomScale, 0.5)
        let contentWidth = PreviewTextWrapLayout.effectiveContentWidth(for: scrollView)
        let horizontalInsets = textContentInset * 2
        let visibleHeight = scrollView.contentView.bounds.height

        let screen = scrollView.window?.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let maxWidthFromContent = max(contentWidth / normalizedScale - horizontalInsets, 160)
        let maxWidthFromScreen = max(screenFrame.width / normalizedScale * 0.95 - horizontalInsets, 160)
        let maxWidth = min(maxWidthFromContent, maxWidthFromScreen)

        let maxHeightFromViewport = max(visibleHeight / normalizedScale * 0.92, 120)
        let maxHeightFromScreen = max(screenFrame.height / normalizedScale * 0.85, 120)
        let maxHeight = min(maxHeightFromViewport, maxHeightFromScreen)

        return Viewport(maxWidth: maxWidth, maxHeight: maxHeight)
    }
}
