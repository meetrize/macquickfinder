import AppKit
import Quartz
import WebKit

/// Office Quick Look 宿主：xlsx/pptx 走 QLWeb2View（WebKit），预览区始终铺满可用空间；缩放只作用于 Web 内容，不放大滚动条。
final class OfficePreviewHostView: NSView {
    private let panCaptureView = PanCaptureView()
    private(set) var qlPreviewView: QLPreviewView?
    private weak var zoomWebView: WKWebView?
    private weak var qlInternalScrollView: NSScrollView?
    private weak var qlInternalDocumentView: NSView?

    private var currentZoomScale: CGFloat = 1.0
    private var panModeEnabled = false
    private var layoutGeneration = 0
    private var baseDocumentSize: NSSize = .zero
    private var usesWebContent = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        panCaptureView.translatesAutoresizingMaskIntoConstraints = false
        panCaptureView.isHidden = true
        panCaptureView.onPan = { [weak self] delta in
            self?.panBy(delta: delta)
        }
        addSubview(panCaptureView)
        NSLayoutConstraint.activate([
            panCaptureView.leadingAnchor.constraint(equalTo: leadingAnchor),
            panCaptureView.trailingAnchor.constraint(equalTo: trailingAnchor),
            panCaptureView.topAnchor.constraint(equalTo: topAnchor),
            panCaptureView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        layoutPreviewToBounds()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutPreviewToBounds()
    }

    func embed(_ qlView: QLPreviewView) {
        if qlPreviewView === qlView {
            layoutPreviewToBounds()
            return
        }
        qlPreviewView?.removeFromSuperview()
        qlPreviewView = qlView
        zoomWebView = nil
        qlInternalScrollView = nil
        qlInternalDocumentView = nil
        baseDocumentSize = .zero
        usesWebContent = false

        qlView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(qlView, positioned: .below, relativeTo: panCaptureView)
        NSLayoutConstraint.activate([
            qlView.leadingAnchor.constraint(equalTo: leadingAnchor),
            qlView.trailingAnchor.constraint(equalTo: trailingAnchor),
            qlView.topAnchor.constraint(equalTo: topAnchor),
            qlView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        layoutPreviewToBounds()
        scheduleContentDiscovery()
    }

    func setZoomScale(_ scale: CGFloat) {
        let clamped = max(0.25, min(scale, 5.0))
        guard abs(clamped - currentZoomScale) > 0.001 else { return }
        currentZoomScale = clamped
        applyZoom()
    }

    func setPanMode(_ enabled: Bool) {
        panModeEnabled = enabled
        panCaptureView.isHidden = !enabled
        panCaptureView.isPanning = false
        updateCursor()
    }

    func resetZoomState() {
        currentZoomScale = 1.0
        zoomWebView = nil
        qlInternalScrollView = nil
        qlInternalDocumentView = nil
        baseDocumentSize = .zero
        usesWebContent = false
        applyZoom()
        scheduleContentDiscovery()
    }

    func handleHostResize() {
        layoutPreviewToBounds()
        if !usesWebContent {
            refreshLegacyDocumentMetrics()
            applyZoom()
        }
    }

    private func layoutPreviewToBounds() {
        guard bounds.width > 1, bounds.height > 1 else { return }
        qlPreviewView?.needsLayout = true
        qlPreviewView?.layoutSubtreeIfNeeded()
    }

    private func scheduleContentDiscovery() {
        layoutGeneration += 1
        let generation = layoutGeneration
        for delay in [0.05, 0.15, 0.35, 0.75, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.layoutGeneration == generation else { return }
                self.discoverPreviewContent()
                self.applyZoom()
            }
        }
    }

    private func discoverPreviewContent() {
        guard let qlView = qlPreviewView else { return }

        if let webView = findWKWebView(in: qlView) {
            usesWebContent = true
            zoomWebView = webView
            qlInternalScrollView = nil
            qlInternalDocumentView = nil
            baseDocumentSize = .zero
            hideInternalScrollIndicators(in: qlView)
            return
        }

        usesWebContent = false
        zoomWebView = nil
        refreshLegacyDocumentMetrics()
    }

    private func refreshLegacyDocumentMetrics() {
        guard let qlView = qlPreviewView else { return }
        hideInternalScrollIndicators(in: qlView)

        let internalScroll = findPrimaryInternalScrollView(in: qlView)
        qlInternalScrollView = internalScroll
        qlInternalDocumentView = internalScroll?.documentView

        guard let docView = internalScroll?.documentView else {
            baseDocumentSize = .zero
            return
        }

        let frame = docView.frame.size
        guard frame.width > 1, frame.height > 1 else {
            baseDocumentSize = .zero
            return
        }
        baseDocumentSize = frame
    }

    private func applyZoom() {
        if usesWebContent, let webView = zoomWebView ?? qlPreviewView.flatMap({ findWKWebView(in: $0) }) {
            zoomWebView = webView
            webView.pageZoom = currentZoomScale
            return
        }

        if let qlWeb = qlPreviewView.flatMap({ findQLWeb2View(in: $0) }) {
            usesWebContent = true
            qlWeb.setValue(currentZoomScale, forKey: "pageZoom")
            return
        }

        applyLegacyDocumentZoom()
    }

    private func applyLegacyDocumentZoom() {
        guard let docView = qlInternalDocumentView ?? qlInternalScrollView?.documentView else { return }
        qlInternalDocumentView = docView

        if baseDocumentSize == .zero {
            let size = docView.frame.size
            if size.width > 1, size.height > 1 {
                baseDocumentSize = size
            }
        }

        let base = baseDocumentSize
        guard base.width > 1, base.height > 1 else { return }

        docView.layer?.setAffineTransform(.identity)
        if abs(currentZoomScale - 1.0) > 0.001 {
            docView.layer?.setAffineTransform(
                CGAffineTransform(scaleX: currentZoomScale, y: currentZoomScale)
            )
        }

        docView.frame = NSRect(
            x: 0,
            y: 0,
            width: base.width * currentZoomScale,
            height: base.height * currentZoomScale
        )
        if let scroll = qlInternalScrollView {
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    private func panBy(delta: NSPoint) {
        if usesWebContent {
            guard let scroll = findWebScrollView() else { return }
            var origin = scroll.contentView.bounds.origin
            origin.x = clamp(origin.x - delta.x, min: 0, max: maxScrollX(for: scroll))
            origin.y = clamp(origin.y - delta.y, min: 0, max: maxScrollY(for: scroll))
            scroll.contentView.setBoundsOrigin(origin)
            scroll.reflectScrolledClipView(scroll.contentView)
            return
        }

        guard let scroll = qlInternalScrollView else { return }
        var origin = scroll.contentView.bounds.origin
        origin.x = clamp(origin.x - delta.x, min: 0, max: maxScrollX(for: scroll))
        origin.y = clamp(origin.y - delta.y, min: 0, max: maxScrollY(for: scroll))
        scroll.contentView.setBoundsOrigin(origin)
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    private func maxScrollX(for scroll: NSScrollView) -> CGFloat {
        guard let docView = scroll.documentView else { return 0 }
        return max(docView.frame.width - scroll.contentView.bounds.width, 0)
    }

    private func maxScrollY(for scroll: NSScrollView) -> CGFloat {
        guard let docView = scroll.documentView else { return 0 }
        return max(docView.frame.height - scroll.contentView.bounds.height, 0)
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }

    private func findWKWebView(in root: NSView) -> WKWebView? {
        if let web = root as? WKWebView { return web }
        for sub in root.subviews {
            if let found = findWKWebView(in: sub) { return found }
        }
        return nil
    }

    private func findQLWeb2View(in root: NSView) -> NSView? {
        let name = String(describing: type(of: root))
        if name == "QLWeb2View" { return root }
        for sub in root.subviews {
            if let found = findQLWeb2View(in: sub) { return found }
        }
        return nil
    }

    private func findWebScrollView() -> NSScrollView? {
        guard let webView = zoomWebView ?? qlPreviewView.flatMap({ findWKWebView(in: $0) }) else { return nil }
        return findPrimaryInternalScrollView(in: webView)
    }

    private func findPrimaryInternalScrollView(in root: NSView) -> NSScrollView? {
        var best: NSScrollView?
        var bestArea: CGFloat = 0

        func visit(_ node: NSView) {
            if let scroll = node as? NSScrollView, let docView = scroll.documentView {
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
        if let scroll = view as? NSScrollView {
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = true
            scroll.autohidesScrollers = true
            scroll.scrollerStyle = .overlay
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
