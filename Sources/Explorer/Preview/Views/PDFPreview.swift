import SwiftUI
import AppKit
import PDFKit

struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument
    @Binding var navigationAction: PDFNavigationAction?
    @Binding var previewTextSelectionActive: Bool
    var onStateChanged: (_ currentPage: Int, _ pageCount: Int, _ scalePercent: Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChanged: onStateChanged)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PreviewPDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        context.coordinator.previewTextSelectionActive = $previewTextSelectionActive
        pdfView.onInteractionStateChanged = { [weak coordinator = context.coordinator] in
            coordinator?.updatePreviewTextSelectionActive(pdfView)
        }
        context.coordinator.installFocusTracking(for: pdfView)
        context.coordinator.onStateChanged = onStateChanged
        context.coordinator.startObserving(pdfView)
        context.coordinator.emitState(from: pdfView)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        context.coordinator.onStateChanged = onStateChanged
        context.coordinator.previewTextSelectionActive = $previewTextSelectionActive
        if let pdfView = nsView as? PreviewPDFView {
            pdfView.onInteractionStateChanged = { [weak coordinator = context.coordinator] in
                coordinator?.updatePreviewTextSelectionActive(pdfView)
            }
            context.coordinator.installFocusTracking(for: pdfView)
        }
        if nsView.document !== document {
            nsView.document = document
            nsView.autoScales = true
            context.coordinator.emitState(from: nsView)
        }

        if let action = navigationAction {
            switch action {
            case .previous:
                nsView.goToPreviousPage(nil)
            case .next:
                nsView.goToNextPage(nil)
            case .goToPage(let pageNumber):
                if let doc = nsView.document,
                   pageNumber >= 1,
                   pageNumber <= doc.pageCount,
                   let page = doc.page(at: pageNumber - 1) {
                    nsView.go(to: page)
                }
            case .zoomIn:
                nsView.autoScales = false
                nsView.scaleFactor = min(nsView.scaleFactor * 1.2, 5.0)
            case .zoomOut:
                nsView.autoScales = false
                nsView.scaleFactor = max(nsView.scaleFactor / 1.2, 0.25)
            case .fitWidth:
                nsView.autoScales = false
                context.coordinator.applyFitWidth(to: nsView)
            case .fitPage:
                nsView.autoScales = true
            }
            // PDFView 的 currentPage/scaleFactor 往往在动作后的下一帧才稳定，异步读取才能实时刷新标题栏状态。
            DispatchQueue.main.async {
                navigationAction = nil
                context.coordinator.emitState(from: nsView)
            }
        }
    }

    final class Coordinator: NSObject, PDFViewDelegate {
        var onStateChanged: (_ currentPage: Int, _ pageCount: Int, _ scalePercent: Int) -> Void
        var previewTextSelectionActive: Binding<Bool>?
        private var pageChangedObserver: NSObjectProtocol?
        private var scaleChangedObserver: NSObjectProtocol?
        private var firstResponderObserver: NSObjectProtocol?
        private weak var observedView: PDFView?

        init(onStateChanged: @escaping (_ currentPage: Int, _ pageCount: Int, _ scalePercent: Int) -> Void) {
            self.onStateChanged = onStateChanged
        }

        deinit {
            stopObserving()
            if let firstResponderObserver {
                NotificationCenter.default.removeObserver(firstResponderObserver)
            }
        }

        func installFocusTracking(for pdfView: PDFView) {
            if firstResponderObserver == nil {
                firstResponderObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: nil,
                    queue: .main
                ) { [weak self, weak pdfView] _ in
                    guard let pdfView else { return }
                    self?.updatePreviewTextSelectionActive(pdfView)
                }
            }
            updatePreviewTextSelectionActive(pdfView)
        }

        func updatePreviewTextSelectionActive(_ pdfView: PDFView) {
            previewTextSelectionActive?.wrappedValue = pdfView.window?.firstResponder === pdfView
        }

        func startObserving(_ pdfView: PDFView) {
            if observedView === pdfView { return }
            stopObserving()
            observedView = pdfView
            let center = NotificationCenter.default
            pageChangedObserver = center.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] note in
                guard let view = note.object as? PDFView else { return }
                self?.emitState(from: view)
            }
            scaleChangedObserver = center.addObserver(
                forName: .PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] note in
                guard let view = note.object as? PDFView else { return }
                self?.emitState(from: view)
            }
        }

        private func stopObserving() {
            let center = NotificationCenter.default
            if let pageChangedObserver { center.removeObserver(pageChangedObserver) }
            if let scaleChangedObserver { center.removeObserver(scaleChangedObserver) }
            pageChangedObserver = nil
            scaleChangedObserver = nil
            observedView = nil
        }

        func emitState(from pdfView: PDFView) {
            let pageCount = pdfView.document?.pageCount ?? 0
            let currentPage: Int
            if let current = pdfView.currentPage,
               let index = pdfView.document?.index(for: current) {
                currentPage = index + 1
            } else {
                currentPage = pageCount > 0 ? 1 : 0
            }
            let scalePercent = Int((pdfView.scaleFactor * 100).rounded())
            onStateChanged(currentPage, pageCount, scalePercent)
        }

        func applyFitWidth(to pdfView: PDFView) {
            guard let page = pdfView.currentPage else { return }
            let pageBounds = page.bounds(for: pdfView.displayBox)
            let availableWidth = max(pdfView.bounds.width - 24, 1)
            let targetScale = availableWidth / max(pageBounds.width, 1)
            pdfView.scaleFactor = max(0.25, min(targetScale, 5.0))
        }
    }
}
