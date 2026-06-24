import SwiftUI
import WebKit

struct HTMLFilePreview: NSViewRepresentable {
    let fileURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        load(into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedPath != fileURL.path else { return }
        load(into: webView, coordinator: context.coordinator)
    }

    private func load(into webView: WKWebView, coordinator: Coordinator) {
        let accessURL = fileURL.deletingLastPathComponent()
        webView.loadFileURL(fileURL, allowingReadAccessTo: accessURL)
        coordinator.lastLoadedPath = fileURL.path
    }

    final class Coordinator {
        var lastLoadedPath: String?
    }
}
