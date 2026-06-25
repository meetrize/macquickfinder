import AppKit
import Quartz
import WebKit

/// Quick Look Office 预览宿主：使用系统 `Office.qlgenerator`（QLPreviewView），xlsx / pptx 分别走 WebKit 或 layer 缩放。
final class OfficePreviewHostView: NSView {
    private enum ZoomBackend {
        /// xlsx：QLWeb2View + pageZoom
        case qlWeb2(NSView)
        /// pptx 等：Office.qlgenerator → QLPDFContainerView，无内置 zoom API
        case pdfContainer
        /// 其他 layer 型 Quick Look 内容
        case layerContainer(NSView)
    }

    private(set) var qlPreviewView: QLPreviewView?

    private var layoutGeneration = 0
    private var appliedZoomScale: CGFloat = 1.0
    private var zoomBackend: ZoomBackend?

    private var lastPublishedPage = -1
    private var lastPublishedPageCount = -1
    private var lastPublishedZoomPercent = -1

    var onStateChanged: ((_ currentPage: Int, _ pageCount: Int, _ zoomPercent: Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clipsToBounds = true
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func embed(_ qlView: QLPreviewView) {
        if qlPreviewView === qlView {
            configureQLView(qlView)
            return
        }

        qlPreviewView?.removeFromSuperview()
        qlPreviewView = qlView
        zoomBackend = nil
        appliedZoomScale = 1.0

        configureQLView(qlView)
        addSubview(qlView)
        NSLayoutConstraint.activate([
            qlView.leadingAnchor.constraint(equalTo: leadingAnchor),
            qlView.trailingAnchor.constraint(equalTo: trailingAnchor),
            qlView.topAnchor.constraint(equalTo: topAnchor),
            qlView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        scheduleContentDiscovery()
    }

    func setPreviewURL(_ url: URL) {
        qlPreviewView?.previewItem = url as NSURL
        zoomBackend = nil
        appliedZoomScale = 1.0
        configureQLView(qlPreviewView)
        scheduleContentDiscovery()
    }

    func resetPreviewState() {
        appliedZoomScale = 1.0
        zoomBackend = nil
        configureQLView(qlPreviewView)
        applyCurrentZoom()
        publishStateIfNeeded(force: true)
    }

    func applyNavigateAction(_ action: OfficePreviewNavigateAction) {
        guard let qlView = qlPreviewView else { return }
        resolveZoomBackend(in: qlView)

        switch action {
        case .previousPage:
            let current = qlCurrentPageIndex(in: qlView)
            qlView.setValue(max(current - 1, 0), forKey: "currentPage")
        case .nextPage:
            let current = qlCurrentPageIndex(in: qlView)
            let maxIndex = max(qlPageCount(in: qlView) - 1, 0)
            qlView.setValue(min(current + 1, maxIndex), forKey: "currentPage")
        case .zoomIn:
            appliedZoomScale = min(appliedZoomScale * 1.2, 5.0)
            applyCurrentZoom()
        case .zoomOut:
            appliedZoomScale = max(appliedZoomScale / 1.2, 0.25)
            applyCurrentZoom()
        case .resetZoom:
            appliedZoomScale = 1.0
            applyCurrentZoom()
        }

        publishStateIfNeeded(force: true)
    }

    func handleHostResize() {
        if case .qlWeb2 = zoomBackend { return }
        applyCurrentZoom()
    }

    private func configureQLView(_ qlView: QLPreviewView?) {
        guard let qlView else { return }
        qlView.translatesAutoresizingMaskIntoConstraints = false
        qlView.autostarts = true
        let manualZoom = abs(appliedZoomScale - 1.0) > 0.001
        qlView.setValue(!manualZoom, forKey: "sizesPreviewToFit")
        qlView.setValue(!manualZoom, forKey: "autoZooms")
    }

    private func scheduleContentDiscovery() {
        layoutGeneration += 1
        let generation = layoutGeneration
        for delay in [0.15, 0.5, 1.0, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.layoutGeneration == generation, let qlView = self.qlPreviewView else { return }
                self.resolveZoomBackend(in: qlView)
                self.enableQuickLookTextSelection(in: qlView)
                self.applyCurrentZoom()
                self.publishStateIfNeeded(force: false)
            }
        }
    }

    /// xlsx Quick Look 使用 QLWeb2View，注入样式以允许鼠标选中单元格文本。
    private func enableQuickLookTextSelection(in qlView: QLPreviewView) {
        guard let webView = findWKWebView(in: qlView) else { return }
        let script = """
        (function() {
          if (document.getElementById('mqf-enable-select')) { return; }
          var style = document.createElement('style');
          style.id = 'mqf-enable-select';
          style.textContent = 'html,body,*{user-select:text !important;-webkit-user-select:text !important;cursor:auto !important;}';
          (document.head || document.documentElement).appendChild(style);
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func resolveZoomBackend(in qlView: QLPreviewView) {
        if let qlWeb2 = findQLWeb2View(in: qlView) {
            zoomBackend = .qlWeb2(qlWeb2)
            return
        }
        if findPDFContainer(in: qlView) != nil {
            zoomBackend = .pdfContainer
            return
        }
        if let layerContainer = findLayerBasedContainer(in: qlView) {
            zoomBackend = .layerContainer(layerContainer)
            return
        }
        zoomBackend = .pdfContainer
    }

    private func applyCurrentZoom() {
        guard let qlView = qlPreviewView else { return }
        if zoomBackend == nil {
            resolveZoomBackend(in: qlView)
        }

        let scale = appliedZoomScale
        let manualZoom = abs(scale - 1.0) > 0.001
        configureQLView(qlView)

        switch zoomBackend {
        case .qlWeb2(let qlWeb2):
            qlWeb2.setValue(scale, forKey: "pageZoom")
            if let wk = findWKWebView(in: qlView) {
                wk.pageZoom = scale
            }

        case .pdfContainer:
            applyPreviewViewLayerZoom(to: qlView, scale: scale, manualZoom: manualZoom)

        case .layerContainer(let container):
            applyPreviewViewLayerZoom(to: qlView, scale: scale, manualZoom: manualZoom)
            // 同步清除旧路径可能在子 layer 上遗留的变换
            container.layer?.setAffineTransform(.identity)

        case nil:
            applyPreviewViewLayerZoom(to: qlView, scale: scale, manualZoom: manualZoom)
        }
    }

    /// pptx（Office.qlgenerator → QLPDFContainerView）无公开 zoom API，对 QLPreviewView 做 layer 缩放。
    private func applyPreviewViewLayerZoom(to qlView: QLPreviewView, scale: CGFloat, manualZoom: Bool) {
        qlView.wantsLayer = true
        guard let layer = qlView.layer else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: qlView.bounds.midX, y: qlView.bounds.midY)
        if manualZoom {
            layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        } else {
            layer.setAffineTransform(.identity)
        }
        CATransaction.commit()
    }

    private func publishStateIfNeeded(force: Bool) {
        guard let qlView = qlPreviewView else { return }
        let pageCount = qlPageCount(in: qlView)
        let currentPage = pageCount > 0 ? qlCurrentPageIndex(in: qlView) + 1 : 0
        let zoomPercent = Int((appliedZoomScale * 100).rounded())

        guard force
            || currentPage != lastPublishedPage
            || pageCount != lastPublishedPageCount
            || zoomPercent != lastPublishedZoomPercent else { return }

        lastPublishedPage = currentPage
        lastPublishedPageCount = pageCount
        lastPublishedZoomPercent = zoomPercent
        onStateChanged?(currentPage, pageCount, zoomPercent)
    }

    private func qlPageCount(in qlView: QLPreviewView) -> Int {
        qlView.value(forKey: "numberOfPages") as? Int ?? 0
    }

    private func qlCurrentPageIndex(in qlView: QLPreviewView) -> Int {
        qlView.value(forKey: "currentPage") as? Int ?? 0
    }

    private func findWKWebView(in root: NSView) -> WKWebView? {
        if let web = root as? WKWebView { return web }
        for sub in root.subviews {
            if let found = findWKWebView(in: sub) { return found }
        }
        return nil
    }

    private func findQLWeb2View(in root: NSView) -> NSView? {
        if String(describing: type(of: root)) == "QLWeb2View" { return root }
        for sub in root.subviews {
            if let found = findQLWeb2View(in: sub) { return found }
        }
        return nil
    }

    private func findPDFContainer(in root: NSView) -> NSView? {
        if String(describing: type(of: root)) == "QLPDFContainerView" { return root }
        for sub in root.subviews {
            if let found = findPDFContainer(in: sub) { return found }
        }
        return nil
    }

    private func findLayerBasedContainer(in root: NSView) -> NSView? {
        if String(describing: type(of: root)) == "QLLayerBasedPreviewContainerView" { return root }
        for sub in root.subviews {
            if let found = findLayerBasedContainer(in: sub) { return found }
        }
        return nil
    }
}
