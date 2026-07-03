import AppKit

/// 文本预览自动换行的布局与段落样式统一配置。
enum PreviewTextWrapLayout {
    static func effectiveContentWidth(for scrollView: NSScrollView) -> CGFloat {
        scrollView.layoutSubtreeIfNeeded()
        scrollView.tile()

        let verticalScrollerWidth: CGFloat = scrollView.hasVerticalScroller
            ? max(scrollView.verticalScroller?.frame.width ?? 0, 0)
            : 0

        let rulerWidth: CGFloat = scrollView.hasVerticalRuler
            ? (scrollView.verticalRulerView?.ruleThickness ?? 0)
            : 0

        let available = scrollView.bounds.width - rulerWidth - verticalScrollerWidth
        let clipWidth = scrollView.contentView.bounds.width
        // 换行切换后 clip view 宽度偶发仍含行号区，取较小值避免文本延伸到行号下方。
        return max(min(clipWidth, available), 1)
    }

    static func configure(textView: NSTextView, scrollView: NSScrollView, wrapLines: Bool) {
        scrollView.hasHorizontalScroller = !wrapLines
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.autoresizingMask = wrapLines ? [.width] : []
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wrapLines
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)

        if wrapLines {
            syncWrapDocumentLayout(textView: textView, scrollView: scrollView)
        } else {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            var frame = textView.frame
            frame.origin.x = 0
            textView.frame = frame
        }
    }

    /// 换行模式下将 document view 锚定在 clip view 左缘，并清除残留水平滚动。
    static func syncWrapDocumentLayout(textView: NSTextView, scrollView: NSScrollView) {
        scrollView.layoutSubtreeIfNeeded()
        scrollView.tile()

        let clipView = scrollView.contentView
        var clipBounds = clipView.bounds
        clipBounds.origin.x = 0
        clipView.bounds = clipBounds
        clipView.scroll(to: NSPoint(x: 0, y: clipBounds.origin.y))

        let width = effectiveContentWidth(for: scrollView)
        var frame = textView.frame
        frame.origin.x = 0
        frame.size.width = width
        textView.frame = frame

        textView.textContainer?.containerSize = NSSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    static func applyParagraphWrapStyle(to textView: NSTextView, wrapLines: Bool) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
        storage.addAttribute(
            .paragraphStyle,
            value: style,
            range: NSRange(location: 0, length: storage.length)
        )
    }

    static func invalidateLayout(textView: NSTextView) {
        if let textContainer = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: textContainer)
        }
        textView.needsLayout = true
        textView.needsDisplay = true
    }

    static func installContentWidthTracking(
        scrollView: NSScrollView,
        textView: NSTextView,
        coordinator: PreviewTextWrapLayoutCoordinator
    ) {
        coordinator.uninstallContentWidthTracking()
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.contentView.postsFrameChangedNotifications = true
        coordinator.boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak scrollView, weak textView, weak coordinator] _ in
            guard
                let scrollView,
                let textView,
                let coordinator,
                coordinator.wrapLinesEnabled
            else { return }
            let width = effectiveContentWidth(for: scrollView)
            guard abs(width - coordinator.lastTrackedContentWidth) > 0.5 else { return }
            coordinator.lastTrackedContentWidth = width
            syncWrapDocumentLayout(textView: textView, scrollView: scrollView)
            invalidateLayout(textView: textView)
        }
    }

    static func scheduleDeferredLayout(textView: NSTextView, scrollView: NSScrollView, wrapLines: Bool) {
        guard wrapLines else { return }
        DispatchQueue.main.async {
            syncWrapDocumentLayout(textView: textView, scrollView: scrollView)
            invalidateLayout(textView: textView)
        }
    }
}

/// 供预览 Coordinator 复用的换行布局追踪状态。
class PreviewTextWrapLayoutCoordinator {
    var wrapLinesEnabled = false
    var lastWrapLines = false
    var lastTrackedContentWidth: CGFloat = 0
    var boundsObserver: NSObjectProtocol?

    func uninstallContentWidthTracking() {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
            self.boundsObserver = nil
        }
    }

    deinit {
        uninstallContentWidthTracking()
    }
}
