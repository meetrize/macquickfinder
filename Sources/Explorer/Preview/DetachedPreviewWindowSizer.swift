import AppKit
import CoreGraphics

enum DetachedPreviewWindowSizer {
    struct LayoutInput {
        var imagePixelSize: CGSize
        var browserStripExpanded: Bool
        var canBrowse: Bool
        var screen: NSScreen?
    }

    /// 计算窗口内容区尺寸：图片预览区与图片 1:1 贴合，宽或高之一撑满屏幕可用范围。
    static func contentSize(for input: LayoutInput) -> CGSize {
        let screen = input.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let backingScale = screen?.backingScaleFactor ?? 2.0
        let imagePoints = CGSize(
            width: max(input.imagePixelSize.width / backingScale, 1),
            height: max(input.imagePixelSize.height / backingScale, 1)
        )

        let belowImageChrome = belowImageChromeHeight(
            browserStripExpanded: input.browserStripExpanded,
            canBrowse: input.canBrowse
        )
        let horizontalMargin: CGFloat = 16
        let verticalMargin: CGFloat = 16
        let topChrome = PanelTopBarMetrics.totalHeight + 1

        let maxImageWidth = max(160, visibleFrame.width - horizontalMargin)
        let maxImageHeight = max(
            120,
            visibleFrame.height - verticalMargin - topChrome - belowImageChrome - titleBarAllowance
        )

        // 等比缩放至屏幕内，允许放大（宽或高之一触达上限）
        let fitScale = min(
            maxImageWidth / imagePoints.width,
            maxImageHeight / imagePoints.height
        )

        let fittedImage = CGSize(
            width: imagePoints.width * fitScale,
            height: imagePoints.height * fitScale
        )

        return CGSize(
            width: max(320, fittedImage.width.rounded(.up)),
            height: max(
                240,
                (topChrome + fittedImage.height + belowImageChrome).rounded(.up)
            )
        )
    }

    static func apply(
        to window: NSWindow,
        imagePixelSize: CGSize,
        browserStripExpanded: Bool,
        canBrowse: Bool
    ) {
        let screen = window.screen ?? NSScreen.main
        var contentSize = contentSize(for: LayoutInput(
            imagePixelSize: imagePixelSize,
            browserStripExpanded: browserStripExpanded,
            canBrowse: canBrowse,
            screen: screen
        ))

        // 确保整窗（含标题栏）不超出屏幕
        if let screen {
            let visibleFrame = screen.visibleFrame
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
            if frame.width > visibleFrame.width || frame.height > visibleFrame.height {
                let scale = min(
                    visibleFrame.width / max(frame.width, 1),
                    visibleFrame.height / max(frame.height, 1),
                    1.0
                )
                contentSize = CGSize(
                    width: max(320, (contentSize.width * scale).rounded(.down)),
                    height: max(240, (contentSize.height * scale).rounded(.down))
                )
            }
        }

        window.setContentSize(contentSize)
        center(window, on: screen)
    }

    static func center(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = visibleFrame.midY - frame.height / 2
        window.setFrame(frame, display: true)
    }

    private static func belowImageChromeHeight(browserStripExpanded: Bool, canBrowse: Bool) -> CGFloat {
        guard canBrowse else { return 0 }
        var height = 1 + PreviewBrowserStripMetrics.navBarHeight
        if browserStripExpanded {
            height += 1 + PreviewBrowserStripMetrics.stripHeight
        }
        return height
    }

    /// unified compact 标题栏在 content rect 之外的部分
    private static let titleBarAllowance: CGFloat = 28
}
