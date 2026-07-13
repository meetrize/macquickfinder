import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewTextToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        let ext = item.url.pathExtension
        var items: [PreviewToolbarOverflowModel] = [
            previewToolbarIconItem(
                id: "text-wrap",
                title: text.wrapEnabled ? L10n.Preview.Toolbar.wrapDisable : L10n.Preview.Toolbar.wrapEnable,
                systemImage: text.wrapEnabled ? "text.justify.left" : "arrow.left.and.right.text.vertical",
                action: { [self] in text.wrapEnabled.toggle() }
            ),
        ]

        if PreviewTypeClassifier.isMarkdownFile(ext) {
            items.append(
                previewToolbarIconItem(
                    id: "md-toggle-mode",
                    title: text.markdownMode == .preview ? L10n.Preview.Toolbar.markdownToSource : L10n.Preview.Toolbar.markdownToPreview,
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
                        title: L10n.Preview.Toolbar.zoomInOverall,
                        systemImage: "plus.magnifyingglass",
                        action: { [self] in text.markdownPreviewScale = min(text.markdownPreviewScale + 0.1, 3.0) }
                    )
                )
                items.append(
                    previewToolbarIconItem(
                        id: "md-zoom-out",
                        title: L10n.Preview.Toolbar.zoomOutOverall,
                        systemImage: "minus.magnifyingglass",
                        isDisabled: text.markdownPreviewScale <= 0.5,
                        action: { [self] in text.markdownPreviewScale = max(text.markdownPreviewScale - 0.1, 0.5) }
                    )
                )
                items.append(
                    PreviewToolbarOverflowModel(
                        id: "md-scale",
                        menuTitle: L10n.Preview.Toolbar.zoomScale,
                        menuSystemImage: "percent",
                        isDisabled: false,
                        estimatedWidth: 44,
                        menuAction: {},
                        content: AnyView(
                            Text("\(Int((text.markdownPreviewScale * 100).rounded()))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .center)
                                .instantHoverTooltip(L10n.Preview.Toolbar.zoomScale)
                        )
                    )
                )
            } else {
                items.append(
                    previewToolbarIconItem(
                        id: "md-font-up",
                        title: L10n.Preview.Toolbar.zoomInFont,
                        systemImage: "plus.magnifyingglass",
                        action: { [self] in text.markdownSourceFontSize = min(text.markdownSourceFontSize + 1, 28) }
                    )
                )
                items.append(
                    previewToolbarIconItem(
                        id: "md-font-down",
                        title: L10n.Preview.Toolbar.zoomOutFont,
                        systemImage: "minus.magnifyingglass",
                        isDisabled: text.markdownSourceFontSize <= 9,
                        action: { [self] in text.markdownSourceFontSize = max(text.markdownSourceFontSize - 1, 9) }
                    )
                )
                items.append(
                    PreviewToolbarOverflowModel(
                        id: "md-font-size",
                        menuTitle: L10n.Preview.Toolbar.fontSize,
                        menuSystemImage: "textformat.size",
                        isDisabled: false,
                        estimatedWidth: 44,
                        menuAction: {},
                        content: AnyView(
                            Text("\(Int(text.markdownSourceFontSize.rounded()))pt")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(minWidth: 44, alignment: .center)
                                .instantHoverTooltip(L10n.Preview.Toolbar.fontSize)
                        )
                    )
                )
            }
        }

        if PreviewTypeClassifier.isHtmlFile(ext) {
            items.append(
                previewToolbarIconItem(
                    id: "html-preview",
                    title: L10n.Preview.Toolbar.htmlPreview,
                    systemImage: text.htmlMode == .preview ? "globe.americas.fill" : "globe.americas",
                    action: { [self] in text.htmlMode = .preview }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "html-source",
                    title: L10n.Preview.Toolbar.sourceMode,
                    systemImage: text.htmlMode == .source ? "doc.plaintext.fill" : "doc.plaintext",
                    action: { [self] in text.htmlMode = .source }
                )
            )
        }

        if !showsPreviewTextSearch(for: item), !PreviewTypeClassifier.isMarkdownFile(ext), !text.isEditing {
            items.append(
                previewToolbarIconItem(
                    id: "text-copy",
                    title: L10n.Preview.Toolbar.copyAll,
                    systemImage: "doc.on.doc",
                    action: { [self] in text.previewAction = .copyAll }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "text-top",
                    title: L10n.Preview.Toolbar.jumpTop,
                    systemImage: "arrow.up.to.line",
                    action: { [self] in text.previewAction = .scrollTop }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "text-bottom",
                    title: L10n.Preview.Toolbar.jumpBottom,
                    systemImage: "arrow.down.to.line",
                    action: { [self] in text.previewAction = .scrollBottom }
                )
            )
        }

        appendTextEditToolbarItems(to: &items, for: item)

        return items
    }

    private func appendTextEditToolbarItems(to items: inout [PreviewToolbarOverflowModel], for item: FileItem) {
        if text.isEditing {
            items.append(
                previewToolbarIconItem(
                    id: "text-save",
                    title: L10n.Preview.TextEdit.save,
                    systemImage: "tray.and.arrow.down",
                    isDisabled: !text.hasUnsavedChanges,
                    action: { [self] in text.previewAction = .save }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "text-revert",
                    title: L10n.Preview.TextEdit.revert,
                    systemImage: "arrow.uturn.backward",
                    isDisabled: !text.hasUnsavedChanges,
                    action: { [self] in text.previewAction = .revert }
                )
            )
            return
        }

        let canEdit = PreviewTextEditEligibility.canOfferEdit(file: item, session: self)
        let denial = PreviewTextEditEligibility.denialReason(for: item, session: self)

        guard canEdit || denial == .contentTruncated || denial == .notWritable else { return }

        let editTitle = denial.flatMap { L10n.Preview.TextEdit.denialTooltip(for: $0) }
            ?? L10n.Preview.TextEdit.edit

        items.append(
            previewToolbarIconItem(
                id: "text-edit",
                title: editTitle,
                systemImage: "square.and.pencil",
                isDisabled: !canEdit,
                action: { [self] in text.previewAction = .beginEdit }
            )
        )
    }
}
