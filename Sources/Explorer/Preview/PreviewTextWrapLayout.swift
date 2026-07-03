import AppKit

/// 文本预览自动换行的布局与段落样式统一配置。
enum PreviewTextWrapLayout {
    static func effectiveContentWidth(for scrollView: NSScrollView) -> CGFloat {
        max(scrollView.contentSize.width, scrollView.bounds.width, 1)
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
            let width = effectiveContentWidth(for: scrollView)
            textView.textContainer?.containerSize = NSSize(
                width: width,
                height: CGFloat.greatestFiniteMagnitude
            )
            if textView.frame.width != width {
                textView.frame.size.width = width
            }
        } else {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
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
            configure(textView: textView, scrollView: scrollView, wrapLines: true)
            invalidateLayout(textView: textView)
        }
    }

    static func scheduleDeferredLayout(textView: NSTextView, scrollView: NSScrollView, wrapLines: Bool) {
        guard wrapLines else { return }
        DispatchQueue.main.async {
            configure(textView: textView, scrollView: scrollView, wrapLines: true)
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
