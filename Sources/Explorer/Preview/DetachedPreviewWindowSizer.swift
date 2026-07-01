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

    /// 计算初始窗口内容区：图片在扣除 chrome 后的可用空间内等比适应，高度紧凑无上下留白。
    static func fitResult(for input: LayoutInput, window: NSWindow) -> FitResult {
        let screen = input.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let placementBounds = DetachedPreviewWindowLayoutMetrics.placementBounds(for: visibleFrame)
        let backingScale = screen?.backingScaleFactor ?? 2.0
        let imagePoints = CGSize(
            width: max(input.imagePixelSize.width / backingScale, 1),
            height: max(input.imagePixelSize.height / backingScale, 1)
        )

        let titleBar = DetachedPreviewWindowLayoutMetrics.titleBarHeight(for: window)
        let topChrome = DetachedPreviewWindowLayoutMetrics.previewChromeHeight
        let belowImageChrome = DetachedPreviewWindowLayoutMetrics.belowImageChromeHeight(
            browserStripExpanded: input.browserStripExpanded,
            canBrowse: input.canBrowse
        )

        let maxFrameHeight = max(120, placementBounds.height)
        let maxContentHeight = max(120, maxFrameHeight - titleBar)
        let imageSlotHeight = max(1, maxContentHeight - topChrome - belowImageChrome)
        let imageSlotWidth = max(1, placementBounds.width)

        var fitScale = min(
            imageSlotWidth / imagePoints.width,
            imageSlotHeight / imagePoints.height
        )

        var fittedImage = CGSize(
            width: imagePoints.width * fitScale,
            height: imagePoints.height * fitScale
        )
        var contentSize = makeContentSize(
            fittedImage: fittedImage,
            topChrome: topChrome,
            belowImageChrome: belowImageChrome
        )

        for _ in 0..<8 {
            let frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
            if frame.width <= placementBounds.width + 0.5,
               frame.height <= maxFrameHeight + 0.5 {
                break
            }
            fitScale *= 0.98
            fittedImage = CGSize(
                width: imagePoints.width * fitScale,
                height: imagePoints.height * fitScale
            )
            contentSize = makeContentSize(
                fittedImage: fittedImage,
                topChrome: topChrome,
                belowImageChrome: belowImageChrome
            )
        }

        return FitResult(contentSize: contentSize)
    }

    @MainActor
    static func applyInitialFit(
        to window: NSWindow,
        imagePixelSize: CGSize,
        browserStripExpanded: Bool,
        canBrowse: Bool
    ) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
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
        placeFrame(
            window: window,
            contentSize: result.contentSize,
            visibleFrame: visibleFrame
        )
        scheduleEdgeSnaps(
            for: window,
            browserStripExpanded: browserStripExpanded,
            canBrowse: canBrowse,
            imagePixelSize: imagePixelSize
        )
    }

    @MainActor
    static func snapToVisibleArea(
        _ window: NSWindow,
        browserStripExpanded: Bool,
        canBrowse: Bool,
        imagePixelSize: CGSize? = nil
    ) {
        guard let screen = window.screen ?? NSScreen.main else {
            DispatchQueue.main.async {
                snapToVisibleArea(
                    window,
                    browserStripExpanded: browserStripExpanded,
                    canBrowse: canBrowse,
                    imagePixelSize: imagePixelSize
                )
            }
            return
        }
        let visibleFrame = screen.visibleFrame
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return }

        if let imagePixelSize, imagePixelSize.width > 0, imagePixelSize.height > 0 {
            let result = fitResult(
                for: LayoutInput(
                    imagePixelSize: imagePixelSize,
                    browserStripExpanded: browserStripExpanded,
                    canBrowse: canBrowse,
                    screen: screen
                ),
                window: window
            )
            placeFrame(
                window: window,
                contentSize: result.contentSize,
                visibleFrame: visibleFrame
            )
        } else {
            clampWindowFrameToVisibleArea(window)
        }
    }

    @MainActor
    static func snapToVisibleArea(for session: PreviewSession?, window: NSWindow) {
        let pixelSize = session.flatMap { session -> CGSize? in
            if session.image.sourcePixelSize.width > 0, session.image.sourcePixelSize.height > 0 {
                return session.image.sourcePixelSize
            }
            return ImageFileDimensionsReader.pixelSize(for: session.file.url)
        }
        snapToVisibleArea(
            window,
            browserStripExpanded: session?.isBrowserStripExpanded ?? true,
            canBrowse: session?.browseContext?.canBrowse ?? false,
            imagePixelSize: pixelSize
        )
    }

    /// 仅把窗口约束在可见区域内，不撑满高度。
    @MainActor
    static func clampWindowFrameToVisibleArea(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let bounds = DetachedPreviewWindowLayoutMetrics.placementBounds(for: visibleFrame)
        guard bounds.width > 0, bounds.height > 0 else { return }

        var frame = window.frame

        if frame.maxY > visibleFrame.maxY {
            frame.origin.y = visibleFrame.maxY - frame.height
        }
        if frame.minY < bounds.minY {
            frame.origin.y = bounds.minY
        }
        if frame.height > bounds.height {
            frame.size.height = bounds.height
            frame.origin.y = bounds.minY
        }
        if frame.width > bounds.width {
            frame.size.width = bounds.width
        }
        frame.origin.x = max(
            bounds.minX,
            min(frame.origin.x, bounds.maxX - frame.width)
        )

        if framesApproximatelyEqual(frame, window.frame) {
            return
        }
        window.setFrame(frame, display: true, animate: false)
    }

    @MainActor
    static func scheduleEdgeSnaps(
        for window: NSWindow,
        browserStripExpanded: Bool,
        canBrowse: Bool,
        imagePixelSize: CGSize?
    ) {
        snapToVisibleArea(
            window,
            browserStripExpanded: browserStripExpanded,
            canBrowse: canBrowse,
            imagePixelSize: imagePixelSize
        )
        DispatchQueue.main.async {
            snapToVisibleArea(
                window,
                browserStripExpanded: browserStripExpanded,
                canBrowse: canBrowse,
                imagePixelSize: imagePixelSize
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            snapToVisibleArea(
                window,
                browserStripExpanded: browserStripExpanded,
                canBrowse: canBrowse,
                imagePixelSize: imagePixelSize
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            snapToVisibleArea(
                window,
                browserStripExpanded: browserStripExpanded,
                canBrowse: canBrowse,
                imagePixelSize: imagePixelSize
            )
        }
    }

    @MainActor
    static func alignWithinVisibleArea(_ window: NSWindow, visibleFrame: CGRect) {
        _ = visibleFrame
        snapToVisibleArea(window, browserStripExpanded: true, canBrowse: true)
    }

    @MainActor
    private static func placeFrame(
        window: NSWindow,
        contentSize: CGSize,
        visibleFrame: CGRect
    ) {
        let bounds = DetachedPreviewWindowLayoutMetrics.placementBounds(for: visibleFrame)
        let snugContent = NSSize(
            width: max(320, contentSize.width.rounded(.down)),
            height: max(120, contentSize.height.rounded(.down))
        )

        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: snugContent))
        if frame.height > bounds.height {
            frame.size.height = bounds.height
        }

        frame.origin.y = visibleFrame.maxY - frame.height
        if frame.minY < bounds.minY {
            frame.origin.y = bounds.minY
        }
        frame.origin.x = bounds.midX - frame.width / 2

        if frame.origin.x < bounds.minX {
            frame.origin.x = bounds.minX
        }
        if frame.maxX > bounds.maxX {
            frame.origin.x = bounds.maxX - frame.width
        }

        if framesApproximatelyEqual(frame, window.frame) {
            return
        }
        window.setFrame(frame, display: true, animate: false)
    }

    private static func framesApproximatelyEqual(_ lhs: NSRect, _ rhs: NSRect, epsilon: CGFloat = 0.5) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < epsilon
            && abs(lhs.origin.y - rhs.origin.y) < epsilon
            && abs(lhs.width - rhs.width) < epsilon
            && abs(lhs.height - rhs.height) < epsilon
    }

    private static func makeContentSize(
        fittedImage: CGSize,
        topChrome: CGFloat,
        belowImageChrome: CGFloat
    ) -> CGSize {
        let trim = DetachedPreviewWindowLayoutMetrics.horizontalImageTrim
        let imageWidth = max(1, fittedImage.width - trim)
        return CGSize(
            width: max(320, imageWidth.rounded(.down)),
            height: topChrome + fittedImage.height.rounded(.down) + belowImageChrome
        )
    }

    /// 非图片类型独立预览窗的初始内容区尺寸（居中于可见屏幕）。
    static func applyInitialContentSize(to window: NSWindow, contentSize: CGSize) {
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        let screen = window.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let placementBounds = DetachedPreviewWindowLayoutMetrics.placementBounds(for: visibleFrame)

        var fittedSize = contentSize
        fittedSize.width = min(fittedSize.width, placementBounds.width)
        fittedSize.height = min(fittedSize.height, max(120, placementBounds.height))

        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: fittedSize))
        frame.origin = NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.midY - frame.height / 2
        )
        window.setFrame(frame, display: true, animate: false)
    }
}
