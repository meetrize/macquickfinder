import SwiftUI
import WebKit

struct EpubPreviewView: View {
    @ObservedObject var session: PreviewSession
    let package: EpubPreviewPackage
    let textContentInset: CGFloat

    private var currentChapterIndex: Int {
        min(max(session.epub.currentChapterIndex, 0), max(package.chapters.count - 1, 0))
    }

    private var currentChapter: EpubChapterPreview {
        package.chapters[currentChapterIndex]
    }

    var body: some View {
        EpubChapterWebPreview(
            chapterURL: currentChapter.fileURL,
            extractedRoot: package.extractedRoot,
            textContentInset: textContentInset
        )
        .onAppear {
            session.epub.clampChapterIndex(chapterCount: package.chapters.count)
        }
        .onChange(of: package.chapters.count) { count in
            session.epub.clampChapterIndex(chapterCount: count)
        }
    }
}

private struct EpubChapterWebPreview: NSViewRepresentable {
    let chapterURL: URL
    let extractedRoot: URL
    var textContentInset: CGFloat = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(textContentInset: textContentInset)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration(coordinator: context.coordinator))
        webView.navigationDelegate = context.coordinator
        load(into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.textContentInset = textContentInset
        let identity = chapterURL.path
        guard context.coordinator.lastLoadedPath != identity else { return }
        load(into: webView, coordinator: context.coordinator)
    }

    private func makeConfiguration(coordinator: Coordinator) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        if textContentInset > 0 {
            configuration.userContentController.addUserScript(coordinator.contentInsetUserScript)
        }
        return configuration
    }

    private func load(into webView: WKWebView, coordinator: Coordinator) {
        webView.loadFileURL(chapterURL, allowingReadAccessTo: extractedRoot)
        coordinator.lastLoadedPath = chapterURL.path
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedPath: String?
        var textContentInset: CGFloat

        init(textContentInset: CGFloat) {
            self.textContentInset = textContentInset
        }

        var contentInsetUserScript: WKUserScript {
            let inset = Int(textContentInset.rounded())
            let source = """
            (function() {
                var style = document.createElement('style');
                style.textContent = 'html { padding: \(inset)px; box-sizing: border-box; } body { margin: 0; }';
                document.documentElement.appendChild(style);
            })();
            """
            return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard textContentInset > 0 else { return }
            let inset = Int(textContentInset.rounded())
            let script = """
            (function() {
                var style = document.getElementById('meofind-preview-content-inset');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'meofind-preview-content-inset';
                    document.documentElement.appendChild(style);
                }
                style.textContent = 'html { padding: \(inset)px; box-sizing: border-box; } body { margin: 0; }';
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}
