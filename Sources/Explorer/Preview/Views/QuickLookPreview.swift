import SwiftUI
import AppKit
import QuickLookUI

struct QuickLookPreview: NSViewRepresentable {
    let url: URL
    let reloadToken: Int
    let navigateRevision: UInt
    let navigateAction: OfficePreviewNavigateAction?
    let onStateChanged: (_ currentPage: Int, _ pageCount: Int, _ zoomScale: CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> OfficePreviewHostView {
        let host = OfficePreviewHostView()
        guard let qlView = QLPreviewView(frame: .zero, style: .normal) else {
            return host
        }
        qlView.previewItem = url as NSURL
        host.onStateChanged = { currentPage, pageCount, zoomPercent in
            onStateChanged(currentPage, pageCount, CGFloat(zoomPercent) / 100.0)
        }
        host.embed(qlView)
        context.coordinator.hostView = host
        context.coordinator.lastReloadToken = reloadToken
        context.coordinator.lastNavigateRevision = navigateRevision
        return host
    }

    func updateNSView(_ host: OfficePreviewHostView, context: Context) {
        context.coordinator.hostView = host
        host.onStateChanged = { currentPage, pageCount, zoomPercent in
            onStateChanged(currentPage, pageCount, CGFloat(zoomPercent) / 100.0)
        }

        if context.coordinator.lastReloadToken != reloadToken {
            guard let qlView = host.qlPreviewView ?? makePreviewView() else { return }
            if host.qlPreviewView == nil {
                host.embed(qlView)
            }
            host.setPreviewURL(url)
            context.coordinator.lastReloadToken = reloadToken
            host.resetPreviewState()
        } else if let qlView = host.qlPreviewView {
            let currentURL = qlView.previewItem?.previewItemURL
            if currentURL?.path != url.path {
                host.setPreviewURL(url)
                host.resetPreviewState()
            }
        } else if let qlView = makePreviewView() {
            host.embed(qlView)
            host.setPreviewURL(url)
        }

        if context.coordinator.lastNavigateRevision != navigateRevision,
           let action = navigateAction {
            host.applyNavigateAction(action)
            context.coordinator.lastNavigateRevision = navigateRevision
        }

        let bounds = host.bounds.size
        if context.coordinator.lastHostBounds != bounds {
            context.coordinator.lastHostBounds = bounds
            host.handleHostResize()
        }
    }

    private func makePreviewView() -> QLPreviewView? {
        guard let view = QLPreviewView(frame: .zero, style: .normal) else { return nil }
        view.previewItem = url as NSURL
        return view
    }

    final class Coordinator {
        weak var hostView: OfficePreviewHostView?
        var lastReloadToken: Int = 0
        var lastNavigateRevision: UInt = 0
        var lastHostBounds: NSSize = .zero
    }
}
