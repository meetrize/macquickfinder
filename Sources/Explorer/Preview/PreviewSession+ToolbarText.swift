import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewTextToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        let ext = item.url.pathExtension
        var items: [PreviewToolbarOverflowModel] = [
            previewToolbarIconItem(
                id: "text-wrap",
                title: text.wrapEnabled ? "关闭自动换行" : "开启自动换行",
                systemImage: text.wrapEnabled ? "text.justify.left" : "arrow.left.and.right.text.vertical",
                action: { [self] in text.wrapEnabled.toggle() }
            ),
        ]

        if PreviewTypeClassifier.isMarkdownFile(ext) {
            items.append(
                previewToolbarIconItem(
                    id: "md-toggle-mode",
                    title: text.markdownMode == .preview ? "切换为源码模式" : "切换为预览模式",
                    systemImage: text.markdownMode == .preview
                        ? "chevron.left.forwardslash.chevron.right"
                        : "eye",
                    action: { [self] in
                        text.markdownMode = text.markdownMode == .preview ? .source : .preview
                    }
                )
            )

            if text.markdownMode == .preview {
                items.append(
                    previewToolbarIconItem(
                        id: "md-zoom-in",
                        title: "放大（整体）",
                        systemImage: "plus.magnifyingglass",
                        action: { [self] in text.markdownPreviewScale = min(text.markdownPreviewScale + 0.1, 3.0) }
                    )
                )
                items.append(
                    previewToolbarIconItem(
                        id: "md-zoom-out",
                        title: "缩小（整体）",
                        systemImage: "minus.magnifyingglass",
                        isDisabled: text.markdownPreviewScale <= 0.5,
                        action: { [self] in text.markdownPreviewScale = max(text.markdownPreviewScale - 0.1, 0.5) }
                    )
                )
                items.append(
                    PreviewToolbarOverflowModel(
                        id: "md-scale",
                        menuTitle: "缩放比例",
                        menuSystemImage: "percent",
                        isDisabled: false,
                        estimatedWidth: 44,
                        menuAction: {},
                        content: AnyView(
                            Text("\(Int((text.markdownPreviewScale * 100).rounded()))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .center)
                                .instantHoverTooltip("缩放比例")
                        )
                    )
                )
            } else {
                items.append(
                    previewToolbarIconItem(
                        id: "md-font-up",
                        title: "放大字体",
                        systemImage: "plus.magnifyingglass",
                        action: { [self] in text.markdownSourceFontSize = min(text.markdownSourceFontSize + 1, 28) }
                    )
                )
                items.append(
                    previewToolbarIconItem(
                        id: "md-font-down",
                        title: "缩小字体",
                        systemImage: "minus.magnifyingglass",
                        isDisabled: text.markdownSourceFontSize <= 9,
                        action: { [self] in text.markdownSourceFontSize = max(text.markdownSourceFontSize - 1, 9) }
                    )
                )
                items.append(
                    PreviewToolbarOverflowModel(
                        id: "md-font-size",
                        menuTitle: "字体大小",
                        menuSystemImage: "textformat.size",
                        isDisabled: false,
                        estimatedWidth: 44,
                        menuAction: {},
                        content: AnyView(
                            Text("\(Int(text.markdownSourceFontSize.rounded()))pt")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .center)
                                .instantHoverTooltip("字体大小")
                        )
                    )
                )
            }
        }

        if PreviewTypeClassifier.isHtmlFile(ext) {
            items.append(
                previewToolbarIconItem(
                    id: "html-preview",
                    title: "HTML 解析预览",
                    systemImage: text.htmlMode == .preview ? "globe.americas.fill" : "globe.americas",
                    action: { [self] in text.htmlMode = .preview }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "html-source",
                    title: "源码模式",
                    systemImage: text.htmlMode == .source ? "doc.plaintext.fill" : "doc.plaintext",
                    action: { [self] in text.htmlMode = .source }
                )
            )
        }

        if showsCodeTextSearch(for: ext) {
            items.append(
                PreviewToolbarOverflowModel(
                    id: "text-search",
                    menuTitle: "搜索",
                    menuSystemImage: "magnifyingglass",
                    isDisabled: false,
                    estimatedWidth: 148,
                    menuAction: {},
                    content: AnyView(PreviewTextSearchToolbarControls(session: self))
                )
            )
        } else if !PreviewTypeClassifier.isMarkdownFile(ext) {
            items.append(
                previewToolbarIconItem(
                    id: "text-copy",
                    title: "复制全文",
                    systemImage: "doc.on.doc",
                    action: { [self] in text.previewAction = .copyAll }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "text-top",
                    title: "跳转顶部",
                    systemImage: "arrow.up.to.line",
                    action: { [self] in text.previewAction = .scrollTop }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "text-bottom",
                    title: "跳转底部",
                    systemImage: "arrow.down.to.line",
                    action: { [self] in text.previewAction = .scrollBottom }
                )
            )
        }

        return items
    }

    private func showsCodeTextSearch(for ext: String) -> Bool {
        guard PreviewTypeClassifier.isCodeFile(ext) else { return false }
        if PreviewTypeClassifier.isHtmlFile(ext), text.htmlMode == .preview { return false }
        return true
    }
}
