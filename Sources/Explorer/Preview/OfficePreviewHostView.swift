import AppKit
import Quartz

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

/// Office 预览宿主：100% 走 QL 内部滚轮；缩放时外层 magnification 放大整页内容，外层滚轮浏览。
final class OfficePreviewHostView: NSView {
    private let scrollView = NSScrollView()
    private let contentContainer = FlippedDocumentView()
    private let panCaptureView = PanCaptureView()
    private(set) var qlPreviewView: QLPreviewView?
    private weak var qlInternalScrollView: NSScrollView?
    private var baseContentSize: NSSize = .zero
    private var currentZoomScale: CGFloat = 1.0
    private var layoutGeneration = 0
    private var panModeEnabled = false
    private var scrollEventMonitor: Any?
    private var scrollMode: ScrollMode = .outer
    private var lastAppliedHostBounds: NSSize = .zero

    private enum ScrollMode {
        case outer
        case qlInternal
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 5.0
        scrollView.magnification = 1.0
        scrollView.documentView = contentContainer

        panCaptureView.translatesAutoresizingMaskIntoConstraints = false
        panCaptureView.isHidden = true
        panCaptureView.onPan = { [weak self] delta in
            self?.panBy(delta: delta)
        }

        addSubview(scrollView)
        addSubview(panCaptureView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),

            panCaptureView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            panCaptureView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            panCaptureView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            panCaptureView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        removeScrollMonitor()
    }

    override func layout() {
        super.layout()
        guard qlPreviewView != nil, bounds.width > 1, bounds.height > 1 else { return }
        let hostBounds = bounds.size
        let boundsChanged = abs(hostBounds.width - lastAppliedHostBounds.width) > 1
            || abs(hostBounds.height - lastAppliedHostBounds.height) > 1
        guard baseContentSize == .zero || boundsChanged else { return }
        lastAppliedHostBounds = hostBounds
        let fraction = scrollFraction()
        _ = refreshDocumentMetrics()
        applyZoomLayout(preserveScrollFraction: fraction)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeScrollMonitor()
        guard window != nil else { return }
        scrollEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let window = self.window, event.window === window else { return event }
            let point = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(point) else { return event }
            guard self.scrollMode == .outer else { return event }
            guard self.outerMaxScrollY > 0 || self.outerMaxScrollX > 0 else { return event }
            self.handleOuterScrollWheel(event)
            return nil
        }
    }

    override func removeFromSuperview() {
        removeScrollMonitor()
        super.removeFromSuperview()
    }

    private func removeScrollMonitor() {
        if let scrollEventMonitor {
            NSEvent.removeMonitor(scrollEventMonitor)
            self.scrollEventMonitor = nil
        }
    }

    private func handleOuterScrollWheel(_ event: NSEvent) {
        let deltaY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 8
        guard deltaY != 0 else { return }
        var origin = scrollView.contentView.bounds.origin
        if event.modifierFlags.contains(.shift) {
            origin.x -= deltaY
        } else {
            origin.y += deltaY
        }
        setOuterScrollOrigin(origin)
    }

    func embed(_ qlView: QLPreviewView) {
        if qlPreviewView === qlView { return }
        qlPreviewView?.removeFromSuperview()
        qlPreviewView = qlView
        baseContentSize = .zero
        qlInternalScrollView = nil
        scrollMode = .outer
        qlView.translatesAutoresizingMaskIntoConstraints = true
        qlView.autoresizingMask = []
        qlView.frame = contentContainer.bounds
        contentContainer.addSubview(qlView)
        lastAppliedHostBounds = .zero
        applyZoomLayout(preserveScrollFraction: 0)
        scheduleLayoutRefresh()
    }

    func setZoomScale(_ scale: CGFloat) {
        let clamped = max(0.25, min(scale, 5.0))
        let scaleChanged = abs(clamped - currentZoomScale) > 0.001
        let needsInitialLayout = baseContentSize == .zero
            || contentContainer.frame.width < 1
            || contentContainer.frame.height < 1
        guard scaleChanged || needsInitialLayout else { return }
        let priorFraction = scrollFraction()
        currentZoomScale = clamped
        _ = refreshDocumentMetrics()
        applyZoomLayout(preserveScrollFraction: priorFraction)
    }

    func setPanMode(_ enabled: Bool) {
        panModeEnabled = enabled
        panCaptureView.isHidden = !enabled
        panCaptureView.isPanning = false
        updateCursor()
    }

    func resetZoomState() {
        currentZoomScale = 1.0
        baseContentSize = .zero
        qlInternalScrollView = nil
        scrollMode = .outer
        lastAppliedHostBounds = .zero
        qlPreviewView?.layer?.setAffineTransform(.identity)
        scrollView.magnification = 1.0
        scrollView.contentView.setBoundsOrigin(.zero)
        applyZoomLayout(preserveScrollFraction: 0)
    }

    private func scheduleLayoutRefresh() {
        layoutGeneration += 1
        let generation = layoutGeneration
        for delay in [0.1, 0.35, 0.75, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.layoutGeneration == generation else { return }
                let fraction = self.scrollFraction()
                _ = self.refreshDocumentMetrics()
                self.applyZoomLayout(preserveScrollFraction: fraction)
            }
        }
    }

    @discardableResult
    private func refreshDocumentMetrics() -> Bool {
        guard let qlView = qlPreviewView else { return false }
        hideInternalScrollIndicators(in: qlView)

        let internalScroll = findPrimaryInternalScrollView(in: qlView)
        qlInternalScrollView = internalScroll

        let measuredSize: NSSize?
        if let docView = internalScroll?.documentView {
            let docFrame = docView.frame.size
            if docFrame.width > 1, docFrame.height > 1 {
                measuredSize = docFrame
            } else {
                measuredSize = nil
            }
        } else {
            measuredSize = nil
        }

        let fallback = qlView.bounds.size
        let candidate = measuredSize ?? (fallback.width > 1 && fallback.height > 1 ? fallback : nil)
        guard let candidate else { return false }

        let width = max(candidate.width, scrollView.contentView.bounds.width, 1)
        let height = max(candidate.height, 1)
        let newSize = NSSize(width: width, height: height)

        let sizeChanged = baseContentSize == .zero
            || abs(baseContentSize.width - newSize.width) > 1
            || abs(baseContentSize.height - newSize.height) > 1
        baseContentSize = newSize
        return sizeChanged
    }

    private func applyZoomLayout(preserveScrollFraction: CGFloat) {
        guard let qlView = qlPreviewView else { return }

        let viewport = scrollView.contentView.bounds.size
        guard baseContentSize.width > 1, baseContentSize.height > 1 else {
            let width = max(viewport.width, bounds.width, 1)
            let height = max(viewport.height, bounds.height, 1)
            contentContainer.setFrameSize(NSSize(width: width, height: height))
            qlView.layer?.setAffineTransform(.identity)
            qlView.frame = NSRect(x: 0, y: 0, width: width, height: height)
            applyOuterMagnification(viewport: viewport)
            updateScrollMode()
            return
        }

        let priorOuterOrigin = scrollView.contentView.bounds.origin
        let priorInternalOrigin = qlInternalScrollView?.contentView.bounds.origin ?? .zero
        let priorVisible = scrollView.documentVisibleRect

        contentContainer.setFrameSize(baseContentSize)
        qlView.layer?.setAffineTransform(.identity)
        qlView.frame = NSRect(origin: .zero, size: baseContentSize)

        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 5.0
        applyOuterMagnification(viewport: viewport, priorVisible: priorVisible)

        if isDocumentZoomActive {
            scrollMode = .outer
            lockInternalScroll()
        } else {
            updateScrollMode()
        }

        switch scrollMode {
        case .outer:
            if outerMaxScrollY > 0 || outerMaxScrollX > 0 {
                var origin = priorOuterOrigin
                if preserveScrollFraction > 0, outerMaxScrollY > 0 {
                    origin.y = preserveScrollFraction * outerMaxScrollY
                }
                setOuterScrollOrigin(origin)
            }
        case .qlInternal:
            let maxY = internalMaxScrollY
            if maxY > 0 {
                var origin = priorInternalOrigin
                if preserveScrollFraction > 0 {
                    origin.y = preserveScrollFraction * maxY
                }
                setInternalScrollOrigin(origin)
            }
        }

        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func applyOuterMagnification(viewport: NSSize, priorVisible: NSRect = .zero) {
        let target = isDocumentZoomActive ? currentZoomScale : 1.0
        guard abs(scrollView.magnification - target) > 0.001 else { return }

        let centerInClip: NSPoint
        if priorVisible.width > 0, priorVisible.height > 0 {
            let center = NSPoint(x: priorVisible.midX, y: priorVisible.midY)
            centerInClip = scrollView.contentView.convert(center, from: contentContainer)
        } else {
            centerInClip = NSPoint(x: viewport.width * 0.5, y: viewport.height * 0.5)
        }
        scrollView.setMagnification(target, centeredAt: centerInClip)
    }

    private var isDocumentZoomActive: Bool {
        abs(currentZoomScale - 1.0) > 0.001
    }

    private func updateScrollMode() {
        if isDocumentZoomActive {
            scrollMode = .outer
            return
        }

        if outerMaxScrollY > 1 || outerMaxScrollX > 1 {
            scrollMode = .outer
            return
        }

        scrollMode = internalMaxScrollY > 1 ? .qlInternal : .outer
    }

    private var outerMaxScrollY: CGFloat {
        let magnification = max(scrollView.magnification, 0.0001)
        let docHeight = baseContentSize.height > 1 ? baseContentSize.height : contentContainer.frame.height
        return max(docHeight * magnification - scrollView.contentView.bounds.height, 0)
    }

    private var outerMaxScrollX: CGFloat {
        let magnification = max(scrollView.magnification, 0.0001)
        let docWidth = baseContentSize.width > 1 ? baseContentSize.width : contentContainer.frame.width
        return max(docWidth * magnification - scrollView.contentView.bounds.width, 0)
    }

    private var internalMaxScrollY: CGFloat {
        guard let internalScroll = qlInternalScrollView,
              let docView = internalScroll.documentView else { return 0 }
        return max(docView.frame.height - internalScroll.contentView.bounds.height, 0)
    }

    private func scrollFraction() -> CGFloat {
        switch scrollMode {
        case .outer:
            guard outerMaxScrollY > 0 else { return 0 }
            return scrollView.contentView.bounds.origin.y / outerMaxScrollY
        case .qlInternal:
            guard let internalScroll = qlInternalScrollView, internalMaxScrollY > 0 else { return 0 }
            return internalScroll.contentView.bounds.origin.y / internalMaxScrollY
        }
    }

    private func panBy(delta: NSPoint) {
        switch scrollMode {
        case .outer:
            var origin = scrollView.contentView.bounds.origin
            origin.x -= delta.x
            origin.y -= delta.y
            setOuterScrollOrigin(origin)
        case .qlInternal:
            guard let internalScroll = qlInternalScrollView else { return }
            var origin = internalScroll.contentView.bounds.origin
            origin.y -= delta.y
            setInternalScrollOrigin(origin)
        }
    }

    private func setOuterScrollOrigin(_ proposed: NSPoint) {
        let origin = NSPoint(
            x: min(max(proposed.x, 0), outerMaxScrollX),
            y: min(max(proposed.y, 0), outerMaxScrollY)
        )
        scrollView.contentView.setBoundsOrigin(origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func setInternalScrollOrigin(_ proposed: NSPoint) {
        guard let internalScroll = qlInternalScrollView else { return }
        let origin = NSPoint(
            x: internalScroll.contentView.bounds.origin.x,
            y: min(max(proposed.y, 0), internalMaxScrollY)
        )
        internalScroll.contentView.setBoundsOrigin(origin)
        internalScroll.reflectScrolledClipView(internalScroll.contentView)
    }

    private func lockInternalScroll() {
        guard let internalScroll = qlInternalScrollView else { return }
        let clip = internalScroll.contentView
        clip.setBoundsOrigin(.zero)
        internalScroll.reflectScrolledClipView(clip)
    }

    private func findPrimaryInternalScrollView(in root: NSView) -> NSScrollView? {
        var best: NSScrollView?
        var bestArea: CGFloat = 0

        func visit(_ node: NSView) {
            if let scroll = node as? NSScrollView, scroll !== scrollView,
               let docView = scroll.documentView {
                let area = docView.frame.width * docView.frame.height
                if area > bestArea {
                    bestArea = area
                    best = scroll
                }
            }
            for sub in node.subviews {
                visit(sub)
            }
        }

        visit(root)
        return best
    }

    private func updateCursor() {
        if panModeEnabled {
            panCaptureView.resetCursor()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func hideInternalScrollIndicators(in view: NSView) {
        if let scroll = view as? NSScrollView, scroll !== scrollView {
            scroll.hasVerticalScroller = false
            scroll.hasHorizontalScroller = false
            scroll.autohidesScrollers = true
            scroll.scrollerStyle = .overlay
        }
        if let scroller = view as? NSScroller {
            scroller.isHidden = true
            scroller.alphaValue = 0
        }
        for sub in view.subviews {
            hideInternalScrollIndicators(in: sub)
        }
    }
}

private final class PanCaptureView: NSView {
    var onPan: ((NSPoint) -> Void)?
    var isPanning = false
    private var lastLocation: NSPoint = .zero

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    func resetCursor() {
        resetCursorRects()
        window?.invalidateCursorRects(for: self)
        if !isPanning {
            NSCursor.openHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        isPanning = true
        lastLocation = event.locationInWindow
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        let location = event.locationInWindow
        let delta = NSPoint(x: location.x - lastLocation.x, y: lastLocation.y - location.y)
        lastLocation = location
        onPan?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        isPanning = false
        NSCursor.openHand.set()
    }
}
