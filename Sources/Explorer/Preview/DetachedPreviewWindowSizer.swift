import AppKit
import CoreGraphics

enum DetachedPreviewWindowSizer {
    struct LayoutInput {
        var imagePixelSize: CGSize
        var browserStripExpanded: Bool
        var canBrowse: Bool
        var screen: NSScreen?
    }

    struct FitResult {
        let contentSize: CGSize
    }

    /// 计算初始窗口内容区：工具栏 + 胶片条高度固定，图片区尽量撑满可用屏幕。
    static func fitResult(for input: LayoutInput, window: NSWindow) -> FitResult {
        let screen = input.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let backingScale = screen?.backingScaleFactor ?? 2.0
        let imagePoints = CGSize(
            width: max(input.imagePixelSize.width / backingScale, 1),
            height: max(input.imagePixelSize.height / backingScale, 1)
        )

        let topChrome = DetachedPreviewWindowLayoutMetrics.previewChromeHeight
        let belowImageChrome = DetachedPreviewWindowLayoutMetrics.belowImageChromeHeight(
            browserStripExpanded: input.browserStripExpanded,
            canBrowse: input.canBrowse
        )

        var fitScale = min(
            visibleFrame.width / imagePoints.width,
            visibleFrame.height / imagePoints.height
        )

        var fittedImage = CGSize(
            width: imagePoints.width * fitScale,
            height: imagePoints.height * fitScale
        )
        var currentContentSize = makeContentSize(
            fittedImage: fittedImage,
            topChrome: topChrome,
            belowImageChrome: belowImageChrome
        )

        for _ in 0..<32 {
            let frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: currentContentSize))
            if frame.maxY <= visibleFrame.maxY + 0.5,
               frame.minY >= visibleFrame.minY - 0.5,
               frame.width <= visibleFrame.width + 0.5 {
                break
            }
            fitScale *= 0.97
            fittedImage = CGSize(
                width: imagePoints.width * fitScale,
                height: imagePoints.height * fitScale
            )
            currentContentSize = makeContentSize(
                fittedImage: fittedImage,
                topChrome: topChrome,
                belowImageChrome: belowImageChrome
            )
        }

        return FitResult(contentSize: currentContentSize)
    }

    @MainActor
    static func applyInitialFit(
        to window: NSWindow,
        imagePixelSize: CGSize,
        browserStripExpanded: Bool,
        canBrowse: Bool
    ) {
        let screen = window.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        let result = fitResult(
            for: LayoutInput(
                imagePixelSize: imagePixelSize,
                browserStripExpanded: browserStripExpanded,
                canBrowse: canBrowse,
                screen: screen
            ),
            window: window
        )

        window.minSize = DetachedPreviewWindowLayoutMetrics.minimumContentSize(
            browserStripExpanded: browserStripExpanded,
            canBrowse: canBrowse
        )
        window.setContentSize(result.contentSize)
        alignWithinVisibleArea(window, visibleFrame: visibleFrame)
    }

    /// 顶部尽量贴齐菜单栏下沿，且整窗完全落在可用区域内（不遮挡标题栏、不侵入 Dock）。
    static func alignWithinVisibleArea(_ window: NSWindow, visibleFrame: CGRect) {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return }
        var frame = window.frame

        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = visibleFrame.maxY - frame.height

        if frame.maxY > visibleFrame.maxY {
            frame.origin.y -= frame.maxY - visibleFrame.maxY
        }
        if frame.minY < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY
        }
        if frame.origin.x < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX
        }
        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = visibleFrame.maxX - frame.width
        }

        window.setFrame(frame, display: true)
    }

    private static func makeContentSize(
        fittedImage: CGSize,
        topChrome: CGFloat,
        belowImageChrome: CGFloat
    ) -> CGSize {
        CGSize(
            width: max(320, fittedImage.width),
            height: topChrome + fittedImage.height + belowImageChrome
        )
    }
}
