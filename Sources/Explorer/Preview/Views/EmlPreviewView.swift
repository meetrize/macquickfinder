import SwiftUI
import WebKit

struct EmlPreviewView: View {
    let content: EmlPreviewContent
    let textContentInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            bodySection
            if !content.attachments.isEmpty {
                Divider()
                attachmentsSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow(label: L10n.Preview.Eml.from, value: content.headers.from)
            headerRow(label: L10n.Preview.Eml.to, value: content.headers.to)
            headerRow(label: L10n.Preview.Eml.cc, value: content.headers.cc)
            headerRow(label: L10n.Preview.Eml.subject, value: content.headers.subject)
            headerRow(label: L10n.Preview.Eml.date, value: content.headers.date)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var bodySection: some View {
        if let htmlBody = content.htmlBody, !htmlBody.isEmpty {
            EmlHTMLWebPreview(html: htmlBody, textContentInset: textContentInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let plainBody = content.plainBody, !plainBody.isEmpty {
            ScrollView {
                Text(plainBody)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(textContentInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text(L10n.Preview.Eml.emptyBody)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Preview.Eml.attachments)
                .font(.subheadline.weight(.semibold))
            ForEach(content.attachments) { attachment in
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .foregroundStyle(.secondary)
                    Text(attachment.fileName)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(L10n.Preview.Eml.attachmentSize(attachment.size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func headerRow(label: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
                Text(value)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct EmlHTMLWebPreview: NSViewRepresentable {
    let html: String
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
        guard context.coordinator.lastLoadedHTML != html else { return }
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
        webView.loadHTMLString(wrappedHTML(html), baseURL: nil)
        coordinator.lastLoadedHTML = html
    }

    private func wrappedHTML(_ html: String) -> String {
        let lower = html.lowercased()
        if lower.contains("<html") {
            return html
        }
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"></head><body>\(html)</body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?
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
