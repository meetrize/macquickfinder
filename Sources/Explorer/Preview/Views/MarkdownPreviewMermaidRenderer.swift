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
        let displaySize: NSSize
        let svg: String?
    }

    static let shared = MarkdownPreviewMermaidRenderer()
    private static let logger = Logger(subsystem: "com.meofind.Explorer", category: "MermaidPreview")

    private static let mermaidJSSource: String = {
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
    }()

    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var isShellReady = false
    private var shellLoadContinuation: CheckedContinuation<Void, Never>?
    private var inflight: [String: Task<RenderResult, Never>] = [:]

    private override init() {
        super.init()
    }

    func render(source: String, layoutWidth: CGFloat, isDark: Bool) async -> RenderResult {
        let key = MarkdownPreviewMermaidBlock.cacheKey(source: source, isDark: isDark)
        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task { await self.renderWithTimeout(source: source, layoutWidth: layoutWidth, isDark: isDark) }
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

    private func renderWithTimeout(source: String, layoutWidth: CGFloat, isDark: Bool) async -> RenderResult {
        await withTaskGroup(of: RenderResult.self) { group in
            group.addTask {
                await self.performRender(source: source, layoutWidth: layoutWidth, isDark: isDark)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                return RenderResult(image: nil, displaySize: .zero, svg: nil)
            }
            guard let first = await group.next() else {
                return RenderResult(image: nil, displaySize: .zero, svg: nil)
            }
            group.cancelAll()
            return first
        }
    }

    private func performRender(source: String, layoutWidth: CGFloat, isDark: Bool) async -> RenderResult {
        guard !Self.mermaidJSSource.isEmpty else {
            Self.logger.error("mermaid.min.js missing or empty in bundle")
            return RenderResult(image: nil, displaySize: .zero, svg: nil)
        }

        let webView = ensureWebView()
        let maxDisplayWidth = max(layoutWidth, 320)
        let prepWidth = max(maxDisplayWidth, 1_200)
        let prepHeight: CGFloat = 8_192
        resizeWebView(webView, to: NSSize(width: prepWidth, height: prepHeight))

        if !isShellReady {
            await loadShell(in: webView)
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
                    source, renderID, theme, maxDisplayWidth, maxDisplayHeight
                  );
                } catch (error) {
                  return { error: String(error && error.message ? error.message : error) };
                }
                """,
                arguments: [
                    "source": source,
                    "renderID": renderID,
                    "theme": theme,
                    "maxDisplayWidth": Double(maxDisplayWidth),
                    "maxDisplayHeight": 3_200.0,
                ],
                in: nil,
                contentWorld: .page
            )

            if let jsError = Self.parseJavaScriptError(value) {
                Self.logger.error("Mermaid JavaScript error: \(jsError, privacy: .public)")
                return RenderResult(image: nil, displaySize: .zero, svg: nil)
            }

            guard let parsed = Self.parseRenderPayload(value) else {
                Self.logger.error(
                    "Mermaid render returned invalid payload: \(String(describing: value), privacy: .public)"
                )
                return RenderResult(image: nil, displaySize: .zero, svg: nil)
            }

            let displaySize = NSSize(width: parsed.width, height: parsed.height)
            let image = await captureWebViewBitmap(
                from: webView,
                contentOrigin: CGPoint(x: parsed.offsetX, y: parsed.offsetY),
                contentSize: displaySize
            ) ?? parsed.svg.flatMap { Self.makeImage(fromSVG: $0, size: displaySize) }

            if image == nil {
                Self.logger.error(
                    "Mermaid bitmap capture failed for \(Int(parsed.width))x\(Int(parsed.height))"
                )
            } else {
                Self.logger.info("Mermaid render succeeded \(Int(parsed.width))x\(Int(parsed.height))")
            }

            return RenderResult(image: image, displaySize: displaySize, svg: parsed.svg)
        } catch {
            Self.logJavaScriptFailure(error, context: "callAsyncJavaScript")
            return RenderResult(image: nil, displaySize: .zero, svg: nil)
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
        let padding: CGFloat = 8
        let captureRect = CGRect(
            x: max(contentOrigin.x - padding, 0),
            y: max(contentOrigin.y - padding, 0),
            width: contentSize.width + padding * 2,
            height: contentSize.height + padding * 2
        )

        webView.layoutSubtreeIfNeeded()
        try? await Task.sleep(nanoseconds: 150_000_000)

        if let snapshot = await takeSnapshot(from: webView, rect: captureRect) {
            return snapshot
        }

        guard let rep = webView.bitmapImageRepForCachingDisplay(in: captureRect) else { return nil }
        webView.cacheDisplay(in: captureRect, to: rep)
        let image = NSImage(size: captureRect.size)
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

    private func loadShell(in webView: WKWebView) async {
        await withCheckedContinuation { continuation in
            shellLoadContinuation = continuation
            webView.loadHTMLString(Self.shellHTML(), baseURL: Bundle.module.resourceURL)
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

    private static func shellHTML() -> String {
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
                padding: 12,
                useMaxWidth: false
              }
            });
            meofindConfiguredTheme = theme;
          }

          function meofindMeasureDiagram(root, svgElement) {
            let width = 0;
            let height = 0;

            try {
              const bbox = svgElement.getBBox();
              width = Math.ceil(bbox.width);
              height = Math.ceil(bbox.height);
            } catch (_) {}

            if (width <= 0 || height <= 0) {
              const vb = svgElement.viewBox && svgElement.viewBox.baseVal;
              if (vb && vb.width > 0 && vb.height > 0) {
                width = Math.ceil(vb.width);
                height = Math.ceil(vb.height);
              }
            }

            if (width <= 0 || height <= 0) {
              const rootRect = root.getBoundingClientRect();
              const svgRect = svgElement.getBoundingClientRect();
              width = Math.ceil(Math.max(
                rootRect.width, svgRect.width, root.scrollWidth, svgElement.scrollWidth || 0
              ));
              height = Math.ceil(Math.max(
                rootRect.height, svgRect.height, root.scrollHeight, svgElement.scrollHeight || 0
              ));
            }

            return { width: width, height: height };
          }

          function meofindApplyDisplayScale(root, svgElement, width, height, maxDisplayWidth, maxDisplayHeight) {
            const maxWidth = Math.max(Number(maxDisplayWidth) || width, 160);
            const maxHeight = Math.max(Number(maxDisplayHeight) || height, 160);
            let scale = 1;
            if (width > maxWidth) {
              scale = maxWidth / width;
            }
            if (height * scale > maxHeight) {
              scale = maxHeight / height;
            }

            root.style.width = "";
            root.style.height = "";
            root.style.overflow = "visible";
            svgElement.style.transform = "";
            svgElement.style.transformOrigin = "";

            if (scale < 1) {
              const scaledWidth = Math.max(Math.ceil(width * scale), 1);
              const scaledHeight = Math.max(Math.ceil(height * scale), 1);
              root.style.width = scaledWidth + "px";
              root.style.height = scaledHeight + "px";
              root.style.overflow = "hidden";
              svgElement.style.transformOrigin = "top left";
              svgElement.style.transform = "scale(" + scale + ")";
              return { width: scaledWidth, height: scaledHeight };
            }

            root.style.width = width + "px";
            root.style.height = height + "px";
            return { width: width, height: height };
          }

          window.meofindRenderDiagram = async function(
            source, renderID, theme, maxDisplayWidth, maxDisplayHeight
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
              requestAnimationFrame(function() {
                requestAnimationFrame(resolve);
              });
            });
            await new Promise(function(resolve) { setTimeout(resolve, 60); });

            const measured = meofindMeasureDiagram(root, svgElement);
            if (measured.width <= 0 || measured.height <= 0) {
              throw new Error("invalid svg size");
            }

            const fitted = meofindApplyDisplayScale(
              root,
              svgElement,
              measured.width,
              measured.height,
              maxDisplayWidth,
              maxDisplayHeight
            );

            await new Promise(function(resolve) {
              requestAnimationFrame(function() {
                requestAnimationFrame(resolve);
              });
            });

            const bounds = root.getBoundingClientRect();
            return {
              svg: new XMLSerializer().serializeToString(svgElement),
              width: fitted.width,
              height: fitted.height,
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
        let width: CGFloat
        let height: CGFloat
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
            let width = numericValue(from: dictionary["width"]),
            let height = numericValue(from: dictionary["height"]),
            width > 0,
            height > 0
        else {
            return nil
        }

        return ParsedPayload(
            svg: dictionary["svg"] as? String,
            width: width,
            height: height,
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
