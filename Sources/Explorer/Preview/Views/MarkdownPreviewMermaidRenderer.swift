import AppKit
import Foundation
import ImageIO
import os
import WebKit

/// 按需离屏 `WKWebView` 渲染 Mermaid 源码为位图，供 Markdown 预览附件使用。
@MainActor
final class MarkdownPreviewMermaidRenderer: NSObject, WKNavigationDelegate {
    struct RenderResult: Equatable {
        let image: NSImage?
        let naturalSize: NSSize
        let svg: String?
    }

    static let shared = MarkdownPreviewMermaidRenderer()
    private static let logger = Logger(subsystem: "com.meofind.Explorer", category: "MermaidPreview")
    private static var mermaidJSSourceCache: String?
    private static var mermaidJSLoadTask: Task<String, Never>?

    /// 启动后空闲预温 Mermaid JS，避免首次打开含 diagram 的 Markdown 时读盘卡顿。
    static func preloadJSSourceIfIdle() {
        Task { @MainActor in
            _ = await loadMermaidJSSource()
        }
    }

    private static func loadMermaidJSSource() async -> String {
        if let mermaidJSSourceCache {
            return mermaidJSSourceCache
        }
        if let mermaidJSLoadTask {
            return await mermaidJSLoadTask.value
        }

        let task = Task<String, Never> {
            await Task.detached(priority: .utility) {
                guard
                    let url = Bundle.module.url(forResource: "mermaid", withExtension: "min.js"),
                    var script = try? String(contentsOf: url, encoding: .utf8)
                else {
                    return ""
                }
                script = script.replacingOccurrences(
                    of: "</script>",
                    with: "<\\/script>",
                    options: .caseInsensitive
                )
                return script
            }.value
        }
        mermaidJSLoadTask = task
        let loaded = await task.value
        mermaidJSSourceCache = loaded
        mermaidJSLoadTask = nil
        return loaded
    }

    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var isShellReady = false
    private var shellLoadContinuation: CheckedContinuation<Void, Never>?
    private var inflight: [String: Task<RenderResult, Never>] = [:]
    /// 串行渲染链：保证同一 WebView 同一时刻只处理一个 diagram。
    private var renderTail: Task<Void, Never> = Task { }

    private override init() {
        super.init()
    }

    func clearCachesOnMemoryPressure() {
        inflight.values.forEach { $0.cancel() }
        inflight.removeAll()
        renderTail = Task { }
        MermaidPreviewCache.shared.clear()
    }

    func render(source: String, isDark: Bool) async -> RenderResult {
        let key = MarkdownPreviewMermaidBlock.cacheKey(source: source, isDark: isDark)
        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task { @MainActor in
            await self.renderTail.value

            let renderTask = Task { @MainActor in
                await self.renderWithTimeout(source: source, isDark: isDark)
            }
            self.renderTail = Task { _ = await renderTask.value }
            return await renderTask.value
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        return result
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            await self.waitForShellReady(in: webView)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            Self.logJavaScriptFailure(error, context: "shell navigation")
            self.finishShellLoad()
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            Self.logJavaScriptFailure(error, context: "shell provisional navigation")
            self.finishShellLoad()
        }
    }

    // MARK: - Private

    private func renderWithTimeout(source: String, isDark: Bool) async -> RenderResult {
        await withTaskGroup(of: RenderResult.self) { group in
            group.addTask {
                await self.performRender(source: source, isDark: isDark)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                return RenderResult(image: nil, naturalSize: .zero, svg: nil)
            }
            guard let first = await group.next() else {
                return RenderResult(image: nil, naturalSize: .zero, svg: nil)
            }
            group.cancelAll()
            return first
        }
    }

    private func performRender(source: String, isDark: Bool) async -> RenderResult {
        let mermaidJSSource = await Self.loadMermaidJSSource()
        guard !mermaidJSSource.isEmpty else {
            Self.logger.error("mermaid.min.js missing or empty in bundle")
            return RenderResult(image: nil, naturalSize: .zero, svg: nil)
        }

        let webView = ensureWebView()
        let prepWidth: CGFloat = 2_048
        let prepHeight: CGFloat = 8_192
        resizeWebView(webView, to: NSSize(width: prepWidth, height: prepHeight))

        if !isShellReady {
            await loadShell(in: webView, mermaidJSSource: mermaidJSSource)
        }

        let renderID = "m" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let theme = isDark ? "dark" : "light"

        do {
            let value = try await webView.callAsyncJavaScript(
                """
                try {
                  if (!window.mermaid) {
                    return { error: "mermaid not loaded" };
                  }
                  if (!window.meofindRenderDiagram) {
                    return { error: "render bridge missing" };
                  }
                  return await window.meofindRenderDiagram(
                    source, renderID, theme
                  );
                } catch (error) {
                  return { error: String(error && error.message ? error.message : error) };
                }
                """,
                arguments: [
                    "source": source,
                    "renderID": renderID,
                    "theme": theme,
                ],
                in: nil,
                contentWorld: .page
            )

            if let jsError = Self.parseJavaScriptError(value) {
                Self.logger.error("Mermaid JavaScript error: \(jsError, privacy: .public)")
                return RenderResult(image: nil, naturalSize: .zero, svg: nil)
            }

            guard let parsed = Self.parseRenderPayload(value) else {
                Self.logger.error(
                    "Mermaid render returned invalid payload: \(String(describing: value), privacy: .public)"
                )
                return RenderResult(image: nil, naturalSize: .zero, svg: nil)
            }

            let naturalSize = NSSize(width: parsed.naturalWidth, height: parsed.naturalHeight)
            let snapshot = await captureWebViewBitmap(
                from: webView,
                contentOrigin: CGPoint(x: parsed.offsetX, y: parsed.offsetY),
                contentSize: naturalSize
            )
            let svg = parsed.svg
            let image: NSImage? = await Task.detached(priority: .userInitiated) {
                if let snapshot {
                    return snapshot
                }
                if let svg {
                    return Self.makeImage(fromSVG: svg, size: naturalSize)
                }
                return nil
            }.value

            if image == nil {
                Self.logger.error(
                    "Mermaid bitmap capture failed for \(Int(parsed.naturalWidth))x\(Int(parsed.naturalHeight))"
                )
            } else {
                Self.logger.info("Mermaid render succeeded \(Int(parsed.naturalWidth))x\(Int(parsed.naturalHeight))")
            }

            return RenderResult(image: image, naturalSize: naturalSize, svg: parsed.svg)
        } catch {
            Self.logJavaScriptFailure(error, context: "callAsyncJavaScript")
            return RenderResult(image: nil, naturalSize: .zero, svg: nil)
        }
    }

    private func resizeWebView(_ webView: WKWebView, to size: NSSize) {
        webView.frame = NSRect(origin: .zero, size: size)
        hostWindow?.setContentSize(size)
        hostWindow?.contentView?.frame = NSRect(origin: .zero, size: size)
    }

    private func captureWebViewBitmap(
        from webView: WKWebView,
        contentOrigin: CGPoint,
        contentSize: NSSize
    ) async -> NSImage? {
        let captureRect = CGRect(
            x: contentOrigin.x,
            y: contentOrigin.y,
            width: contentSize.width,
            height: contentSize.height
        )

        webView.layoutSubtreeIfNeeded()

        if let snapshot = await takeSnapshot(from: webView, rect: captureRect) {
            snapshot.size = contentSize
            return snapshot
        }

        guard let rep = webView.bitmapImageRepForCachingDisplay(in: captureRect) else { return nil }
        webView.cacheDisplay(in: captureRect, to: rep)
        let image = NSImage(size: contentSize)
        image.addRepresentation(rep)
        return image
    }

    private func takeSnapshot(from webView: WKWebView, rect: CGRect) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let configuration = WKSnapshotConfiguration()
            configuration.rect = rect
            webView.takeSnapshot(with: configuration) { image, error in
                if let error {
                    Self.logger.error("takeSnapshot failed: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume(returning: image)
            }
        }
    }

    private func loadShell(in webView: WKWebView, mermaidJSSource: String) async {
        await withCheckedContinuation { continuation in
            shellLoadContinuation = continuation
            webView.loadHTMLString(Self.shellHTML(mermaidJSSource: mermaidJSSource), baseURL: Bundle.module.resourceURL)
        }
    }

    private func waitForShellReady(in webView: WKWebView) async {
        guard !isShellReady else { return }

        for _ in 0..<200 {
            let ready = await Self.isMermaidReady(in: webView)
            if ready {
                finishShellLoad()
                return
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        Self.logger.error("Timed out waiting for mermaid to load in shell")
        finishShellLoad()
    }

    private func finishShellLoad() {
        guard !isShellReady else { return }
        isShellReady = true
        shellLoadContinuation?.resume()
        shellLoadContinuation = nil
    }

    private static func isMermaidReady(in webView: WKWebView) async -> Bool {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(
                "Boolean(window.mermaid) && typeof window.meofindRenderDiagram === 'function'"
            ) { value, _ in
                continuation.resume(returning: (value as? Bool) == true)
            }
        }
    }

    private func ensureWebView() -> WKWebView {
        if let webView {
            return webView
        }

        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1_200, height: 1_200), configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_200, height: 1_200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.01
        window.contentView = webView
        window.orderFrontRegardless()

        self.webView = webView
        hostWindow = window
        return webView
    }

    private static func shellHTML(mermaidJSSource: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              background: #ffffff;
            }
            #diagram-root {
              display: inline-block;
              line-height: 0;
            }
            #diagram-root svg {
              display: block;
              max-width: none;
              height: auto;
            }
            .nodeLabel, .label, .edgeLabel {
              color: inherit !important;
            }
          </style>
          <script>\(mermaidJSSource)</script>
          <script>
          let meofindConfiguredTheme = null;

          function meofindThemeVariables(theme) {
            if (theme === "dark") {
              return {
                darkMode: true,
                background: "#1e1e1e",
                primaryColor: "#2d2d2d",
                primaryBorderColor: "#d0d0d0",
                primaryTextColor: "#f5f5f5",
                secondaryColor: "#2d2d2d",
                secondaryBorderColor: "#d0d0d0",
                secondaryTextColor: "#f5f5f5",
                tertiaryColor: "#2d2d2d",
                tertiaryBorderColor: "#d0d0d0",
                tertiaryTextColor: "#f5f5f5",
                lineColor: "#d0d0d0",
                textColor: "#f5f5f5",
                mainBkg: "#2d2d2d",
                nodeBorder: "#d0d0d0",
                clusterBkg: "#2d2d2d",
                clusterBorder: "#d0d0d0",
                titleColor: "#f5f5f5",
                edgeLabelBackground: "#2d2d2d"
              };
            }
            return {
              darkMode: false,
              background: "#ffffff",
              primaryColor: "#ffffff",
              primaryBorderColor: "#000000",
              primaryTextColor: "#000000",
              secondaryColor: "#ffffff",
              secondaryBorderColor: "#000000",
              secondaryTextColor: "#000000",
              tertiaryColor: "#ffffff",
              tertiaryBorderColor: "#000000",
              tertiaryTextColor: "#000000",
              lineColor: "#000000",
              textColor: "#000000",
              mainBkg: "#ffffff",
              nodeBorder: "#000000",
              clusterBkg: "#ffffff",
              clusterBorder: "#000000",
              titleColor: "#000000",
              edgeLabelBackground: "#ffffff"
            };
          }

          function meofindEnsureMermaid(theme) {
            if (!window.mermaid) {
              throw new Error("mermaid not loaded");
            }
            if (meofindConfiguredTheme === theme) {
              return;
            }
            const themeVariables = meofindThemeVariables(theme);
            mermaid.initialize({
              startOnLoad: false,
              theme: "base",
              themeVariables: themeVariables,
              securityLevel: "loose",
              flowchart: {
                htmlLabels: true,
                curve: "linear",
                padding: 16,
                useMaxWidth: false
              },
              gantt: {
                useMaxWidth: false,
                fontSize: 16,
                barHeight: 22,
                barGap: 6
              }
            });
            meofindConfiguredTheme = theme;
          }

          function meofindNaturalSize(root, svgElement) {
            const padX = 8;
            const padTop = 8;
            const padBottom = 14;

            try {
              const bbox = svgElement.getBBox();
              const x = bbox.x - padX;
              const y = bbox.y - padTop;
              const width = bbox.width + padX * 2;
              const height = bbox.height + padTop + padBottom;
              svgElement.setAttribute("viewBox", x + " " + y + " " + width + " " + height);
              return { width: Math.ceil(width), height: Math.ceil(height) };
            } catch (_) {}

            const rootRect = root.getBoundingClientRect();
            if (rootRect.width > 0 && rootRect.height > 0) {
              const width = Math.ceil(rootRect.width) + padX * 2;
              const height = Math.ceil(rootRect.height) + padTop + padBottom;
              svgElement.setAttribute("viewBox", "0 0 " + width + " " + height);
              return { width: width, height: height };
            }

            const vb = svgElement.viewBox && svgElement.viewBox.baseVal;
            if (vb && vb.width > 0 && vb.height > 0) {
              const width = Math.ceil(vb.width) + padX * 2;
              const height = Math.ceil(vb.height) + padTop + padBottom;
              return { width: width, height: height };
            }

            return { width: 0, height: 0 };
          }

          function meofindFitToDisplay(root, svgElement, naturalWidth, naturalHeight, targetWidth) {
            const target = Math.max(Number(targetWidth) || naturalWidth, 160);
            const scale = target / naturalWidth;
            const displayWidth = Math.max(Math.ceil(naturalWidth * scale), 1);
            const displayHeight = Math.max(Math.ceil(naturalHeight * scale), 1);

            svgElement.setAttribute("width", String(displayWidth));
            svgElement.setAttribute("height", String(displayHeight));
            svgElement.style.transform = "";
            svgElement.style.transformOrigin = "";
            svgElement.style.maxWidth = "none";

            root.style.width = displayWidth + "px";
            root.style.height = displayHeight + "px";
            root.style.overflow = "visible";
            root.style.paddingBottom = "0";

            return { width: displayWidth, height: displayHeight };
          }

          window.meofindRenderDiagram = async function(
            source, renderID, theme
          ) {
            meofindEnsureMermaid(theme);

            const themeVariables = meofindThemeVariables(theme);
            const background = themeVariables.background;
            document.documentElement.style.background = background;
            document.body.style.background = background;

            document.getElementById("d" + renderID)?.remove();
            document.getElementById(renderID)?.remove();
            document.getElementById("diagram-root")?.remove();

            const { svg } = await mermaid.render(renderID, source);
            const root = document.createElement("div");
            root.id = "diagram-root";
            root.innerHTML = svg;
            const svgElement = root.querySelector("svg");
            if (!svgElement) {
              throw new Error("missing svg element");
            }

            document.body.appendChild(root);

            await new Promise(function(resolve) {
              requestAnimationFrame(resolve);
            });

            const natural = meofindNaturalSize(root, svgElement);
            if (natural.width <= 0 || natural.height <= 0) {
              throw new Error("invalid svg size");
            }

            svgElement.setAttribute("width", String(natural.width));
            svgElement.setAttribute("height", String(natural.height));
            root.style.width = natural.width + "px";
            root.style.height = natural.height + "px";

            await new Promise(function(resolve) {
              requestAnimationFrame(resolve);
            });

            const bounds = root.getBoundingClientRect();
            return {
              svg: new XMLSerializer().serializeToString(svgElement),
              naturalWidth: natural.width,
              naturalHeight: natural.height,
              offsetX: bounds.left,
              offsetY: bounds.top
            };
          };
          </script>
        </head>
        <body></body>
        </html>
        """
    }

    private static func logJavaScriptFailure(_ error: Error, context: String) {
        let nsError = error as NSError
        let jsMessage = nsError.userInfo["WKJavaScriptExceptionMessage"] as? String
        let jsLine = nsError.userInfo["WKJavaScriptExceptionLineNumber"]
        let jsColumn = nsError.userInfo["WKJavaScriptExceptionColumnNumber"]
        if let jsMessage {
            logger.error(
                "Mermaid \(context) failed at \(String(describing: jsLine), privacy: .public):\(String(describing: jsColumn), privacy: .public): \(jsMessage, privacy: .public)"
            )
        } else {
            logger.error("Mermaid \(context) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private struct ParsedPayload {
        let svg: String?
        let naturalWidth: CGFloat
        let naturalHeight: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
    }

    private static func parseJavaScriptError(_ value: Any?) -> String? {
        let dictionary = dictionaryValue(from: value)
        return dictionary?["error"] as? String
    }

    private static func parseRenderPayload(_ value: Any?) -> ParsedPayload? {
        if parseJavaScriptError(value) != nil {
            return nil
        }

        guard let dictionary = dictionaryValue(from: value) else { return nil }

        guard
            let naturalWidth = numericValue(from: dictionary["naturalWidth"]),
            let naturalHeight = numericValue(from: dictionary["naturalHeight"]),
            naturalWidth > 0,
            naturalHeight > 0
        else {
            return nil
        }

        return ParsedPayload(
            svg: dictionary["svg"] as? String,
            naturalWidth: naturalWidth,
            naturalHeight: naturalHeight,
            offsetX: numericValue(from: dictionary["offsetX"]) ?? 0,
            offsetY: numericValue(from: dictionary["offsetY"]) ?? 0
        )
    }

    private static func dictionaryValue(from value: Any?) -> [String: Any]? {
        if let direct = value as? [String: Any] {
            return direct
        }
        if let nsDict = value as? NSDictionary {
            return nsDict as? [String: Any]
        }
        return nil
    }

    private static func numericValue(from value: Any?) -> CGFloat? {
        switch value {
        case let number as NSNumber:
            return CGFloat(number.doubleValue)
        case let double as Double:
            return CGFloat(double)
        case let float as Float:
            return CGFloat(float)
        case let int as Int:
            return CGFloat(int)
        default:
            return nil
        }
    }

    nonisolated static func makeImage(fromSVG svg: String, size: NSSize) -> NSImage? {
        var markup = svg.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !markup.isEmpty else { return nil }

        if !markup.lowercased().contains("xmlns=") {
            markup = markup.replacingOccurrences(
                of: "<svg",
                with: "<svg xmlns=\"http://www.w3.org/2000/svg\"",
                options: .caseInsensitive
            )
        }

        guard let data = markup.data(using: .utf8) else { return nil }

        if
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        {
            return NSImage(cgImage: cgImage, size: size)
        }

        if let image = NSImage(data: data), image.isValid, image.size.width > 0, image.size.height > 0 {
            image.size = size
            return image
        }

        return nil
    }
}
