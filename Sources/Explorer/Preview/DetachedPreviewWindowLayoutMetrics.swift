import AppKit

enum DetachedPreviewWindowLayoutMetrics {
    static var previewChromeHeight: CGFloat { PanelTopBarMetrics.totalHeight + chromeDividerHeight }

    /// 略收窄内容宽度，消除图片与窗口左右边缘的细缝。
    static let horizontalImageTrim: CGFloat = 14

    static let chromeDividerHeight: CGFloat = 1

    /// 布局计量留一点余量，避免圆角 / 分隔线导致底部栏被裁切。
    static let layoutSlack: CGFloat = 2

    /// 窗口底边高于 Dock / 任务栏上沿的间距，避免底部状态栏被遮挡。
    static let bottomMarginFromDock: CGFloat = 14

    static func placementBounds(for visibleFrame: CGRect) -> CGRect {
        let inset = bottomMarginFromDock
        return CGRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY + inset,
            width: visibleFrame.width,
            height: max(120, visibleFrame.height - inset)
        )
    }

    static func belowImageChromeHeight(browserStripExpanded: Bool, canBrowse: Bool) -> CGFloat {
        guard canBrowse else { return 0 }
        var height: CGFloat = 0
        if browserStripExpanded {
            height += chromeDividerHeight + PreviewBrowserStripMetrics.stripHeight
        }
        height += chromeDividerHeight + PreviewBrowserStripMetrics.navBarHeight
        return height + layoutSlack
    }

    static func totalFixedContentChromeHeight(browserStripExpanded: Bool, canBrowse: Bool) -> CGFloat {
        previewChromeHeight + belowImageChromeHeight(
            browserStripExpanded: browserStripExpanded,
            canBrowse: canBrowse
        )
    }

    static func titleBarHeight(for window: NSWindow) -> CGFloat {
        if let measured = measuredTitleBarHeight(for: window), measured >= 20 {
            return measured
        }
        let probeContent = NSSize(width: 200, height: 200)
        let frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: probeContent))
        return max(28, frame.height - probeContent.height)
    }

    static func measuredTitleBarHeight(for window: NSWindow) -> CGFloat? {
        guard window.frame.height > 0,
              let contentView = window.contentView,
              contentView.frame.height > 0 else {
            return nil
        }
        let measured = window.frame.height - contentView.frame.height
        return measured > 0 ? measured : nil
    }

    static func contentSafeAreaTop(for window: NSWindow) -> CGFloat {
        window.contentView?.safeAreaInsets.top ?? 0
    }

    static func contentSafeAreaBottom(for window: NSWindow) -> CGFloat {
        window.contentView?.safeAreaInsets.bottom ?? 0
    }

    static func minimumContentSize(browserStripExpanded: Bool, canBrowse: Bool) -> NSSize {
        let below = belowImageChromeHeight(
            browserStripExpanded: browserStripExpanded,
            canBrowse: canBrowse
        )
        return NSSize(
            width: 320,
            height: previewChromeHeight + 80 + below
        )
    }
}
