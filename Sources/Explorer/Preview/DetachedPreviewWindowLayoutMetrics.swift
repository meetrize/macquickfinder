import AppKit

enum DetachedPreviewWindowLayoutMetrics {
    static var previewChromeHeight: CGFloat { PanelTopBarMetrics.totalHeight + 1 }

    static func belowImageChromeHeight(browserStripExpanded: Bool, canBrowse: Bool) -> CGFloat {
        guard canBrowse else { return 0 }
        var height = 1 + PreviewBrowserStripMetrics.navBarHeight
        if browserStripExpanded {
            height += 1 + PreviewBrowserStripMetrics.stripHeight
        }
        return height
    }

    static func titleBarHeight(for window: NSWindow) -> CGFloat {
        let probeContent = NSSize(width: 200, height: 200)
        let frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: probeContent))
        return max(0, frame.height - probeContent.height)
    }

    static func contentSafeAreaTop(for window: NSWindow) -> CGFloat {
        window.contentView?.safeAreaInsets.top ?? 0
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
