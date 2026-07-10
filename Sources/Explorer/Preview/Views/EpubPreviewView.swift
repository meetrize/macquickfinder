import SwiftUI
import WebKit

private enum EpubChapterScrollEdge {
    case top
    case bottom
}

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
            textContentInset: textContentInset,
            onPreviousChapter: {
                session.epub.showPreviousChapter()
            },
            onNextChapter: {
                session.epub.showNextChapter(chapterCount: package.chapters.count)
            }
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
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            textContentInset: textContentInset,
            onPreviousChapter: onPreviousChapter,
            onNextChapter: onNextChapter
        )
    }

    func makeNSView(context: Context) -> EpubChapterWebView {
        let webView = EpubChapterWebView(frame: .zero, configuration: makeConfiguration(coordinator: context.coordinator))
        webView.navigationDelegate = context.coordinator
        webView.scrollDelegate = context.coordinator
        load(into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: EpubChapterWebView, context: Context) {
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

    private func load(into webView: EpubChapterWebView, coordinator: Coordinator) {
        webView.loadFileURL(chapterURL, allowingReadAccessTo: extractedRoot)
        coordinator.lastLoadedPath = chapterURL.path
    }

    final class Coordinator: NSObject, WKNavigationDelegate, EpubChapterWebViewScrollDelegate {
        var lastLoadedPath: String?
        var textContentInset: CGFloat
        var pendingScrollEdge: EpubChapterScrollEdge?
        private let onPreviousChapter: () -> Void
        private let onNextChapter: () -> Void

        init(
            textContentInset: CGFloat,
            onPreviousChapter: @escaping () -> Void,
            onNextChapter: @escaping () -> Void
        ) {
            self.textContentInset = textContentInset
            self.onPreviousChapter = onPreviousChapter
            self.onNextChapter = onNextChapter
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

        func epubWebViewDidRequestPreviousChapter(_ webView: EpubChapterWebView) {
            pendingScrollEdge = .bottom
            onPreviousChapter()
        }

        func epubWebViewDidRequestNextChapter(_ webView: EpubChapterWebView) {
            pendingScrollEdge = .top
            onNextChapter()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyContentInsetIfNeeded(to: webView)
            applyPendingScrollEdge(to: webView)
            if let epubWebView = webView as? EpubChapterWebView {
                epubWebView.refreshScrollEdges()
            }
        }

        private func applyContentInsetIfNeeded(to webView: WKWebView) {
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

        private func applyPendingScrollEdge(to webView: WKWebView) {
            guard let edge = pendingScrollEdge else { return }
            pendingScrollEdge = nil
            let script: String
            switch edge {
            case .top:
                script = "window.scrollTo(0, 0);"
            case .bottom:
                script = """
                (function() {
                    var el = document.scrollingElement || document.documentElement;
                    window.scrollTo(0, Math.max(0, el.scrollHeight - el.clientHeight));
                })();
                """
            }
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}

private protocol EpubChapterWebViewScrollDelegate: AnyObject {
    func epubWebViewDidRequestPreviousChapter(_ webView: EpubChapterWebView)
    func epubWebViewDidRequestNextChapter(_ webView: EpubChapterWebView)
}

private final class EpubChapterWebView: WKWebView {
    weak var scrollDelegate: EpubChapterWebViewScrollDelegate?

    private(set) var isAtTop = true
    private(set) var isAtBottom = false
    private var pagingCooldown = false

    override func scrollWheel(with event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        if !pagingCooldown, abs(deltaY) > 0.5 {
            if isAtBottom, deltaY < 0 {
                beginPagingCooldown()
                scrollDelegate?.epubWebViewDidRequestNextChapter(self)
                return
            }
            if isAtTop, deltaY > 0 {
                beginPagingCooldown()
                scrollDelegate?.epubWebViewDidRequestPreviousChapter(self)
                return
            }
        }
        super.scrollWheel(with: event)
        refreshScrollEdges()
    }

    func refreshScrollEdges() {
        let script = """
        (function() {
            var el = document.scrollingElement || document.documentElement;
            var maxScroll = Math.max(0, el.scrollHeight - el.clientHeight);
            return {
                top: el.scrollTop <= 2,
                bottom: el.scrollTop >= maxScroll - 2
            };
        })();
        """
        evaluateJavaScript(script) { [weak self] result, _ in
            guard let self, let dict = result as? [String: Bool] else { return }
            self.isAtTop = dict["top"] ?? true
            self.isAtBottom = dict["bottom"] ?? false
        }
    }

    private func beginPagingCooldown() {
        pagingCooldown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.pagingCooldown = false
        }
    }
}
