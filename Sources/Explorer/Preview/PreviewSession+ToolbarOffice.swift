import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewOfficeToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        if content.officeURL != nil {
            return previewQuickLookOfficeToolbarItems(for: item)
        }
        return previewOfficeRichTextToolbarItems()
    }

    func previewSpreadsheetToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        var items: [PreviewToolbarOverflowModel] = []

        if !content.textContent.isEmpty {
            items.append(
                previewToolbarIconItem(
                    id: "spreadsheet-toggle-mode",
                    title: office.spreadsheetMode == .text
                        ? L10n.Preview.Toolbar.spreadsheetToQuickLook
                        : L10n.Preview.Toolbar.spreadsheetToText,
                    systemImage: office.spreadsheetMode == .text ? "tablecells" : "doc.plaintext",
                    action: { [self] in
                        office.spreadsheetMode = office.spreadsheetMode == .text ? .quickLook : .text
                    }
                )
            )
        }

        if office.spreadsheetMode == .quickLook {
            items.append(contentsOf: previewQuickLookOfficeToolbarItems(for: item))
        } else {
            items.append(
                previewToolbarIconItem(
                    id: "spreadsheet-wrap",
                    title: text.wrapEnabled ? L10n.Preview.Toolbar.wrapDisable : L10n.Preview.Toolbar.wrapEnable,
                    systemImage: text.wrapEnabled ? "text.justify.left" : "arrow.left.and.right.text.vertical",
                    action: { [self] in text.wrapEnabled.toggle() }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "spreadsheet-copy",
                    title: L10n.Preview.Toolbar.copyAll,
                    systemImage: "doc.on.doc",
                    action: { [self] in text.previewAction = .copyAll }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "spreadsheet-top",
                    title: L10n.Preview.Toolbar.jumpTop,
                    systemImage: "arrow.up.to.line",
                    action: { [self] in text.previewAction = .scrollTop }
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "spreadsheet-bottom",
                    title: L10n.Preview.Toolbar.jumpBottom,
                    systemImage: "arrow.down.to.line",
                    action: { [self] in text.previewAction = .scrollBottom }
                )
            )
        }

        return items
    }

    private func previewQuickLookOfficeToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        let ext = item.url.pathExtension.lowercased()
        let showsPageControls = BuiltinPreviewExtensions.presentation.contains(ext) || office.pageCount > 1
        var items: [PreviewToolbarOverflowModel] = []
        if showsPageControls {
            items.append(
                previewToolbarIconItem(
                    id: "office-prev",
                    title: L10n.Preview.Toolbar.previousPage,
                    systemImage: "chevron.left",
                    isDisabled: office.pageCount > 0 && office.currentPage <= 1,
                    action: { [self] in office.sendNavigate(.previousPage) }
                )
            )
        }
        items.append(contentsOf: [
            previewToolbarIconItem(
                id: "office-zoom-out",
                title: L10n.Preview.Toolbar.zoomOut,
                systemImage: "minus.magnifyingglass",
                isDisabled: office.zoomScale <= 0.25,
                action: { [self] in office.sendNavigate(.zoomOut) }
            ),
            PreviewToolbarOverflowModel(
                id: "office-scale",
                menuTitle: L10n.Preview.Toolbar.zoomScale,
                menuSystemImage: "percent",
                isDisabled: false,
                estimatedWidth: 44,
                menuAction: {},
                content: AnyView(
                    Text("\(Int((office.zoomScale * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                        .instantHoverTooltip(L10n.Preview.Toolbar.zoomScale)
                )
            ),
            previewToolbarIconItem(
                id: "office-zoom-in",
                title: L10n.Preview.Toolbar.zoomIn,
                systemImage: "plus.magnifyingglass",
                isDisabled: office.zoomScale >= 5.0,
                action: { [self] in office.sendNavigate(.zoomIn) }
            ),
            previewToolbarIconItem(
                id: "office-reset",
                title: L10n.Preview.Toolbar.reset,
                systemImage: "arrow.counterclockwise",
                isDisabled: abs(office.zoomScale - 1.0) < 0.001,
                action: { [self] in office.sendNavigate(.resetZoom) }
            ),
        ])
        if showsPageControls {
            items.append(
                PreviewToolbarOverflowModel(
                    id: "office-page",
                    menuTitle: L10n.Preview.Toolbar.pageNumber,
                    menuSystemImage: "number",
                    isDisabled: false,
                    estimatedWidth: 56,
                    menuAction: {},
                    content: AnyView(
                        Text(office.pageCount > 0 ? "\(office.currentPage)/\(office.pageCount)" : "…")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(minWidth: 56, alignment: .center)
                            .instantHoverTooltip(L10n.Preview.Toolbar.pageNumber)
                    )
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "office-next",
                    title: L10n.Preview.Toolbar.nextPage,
                    systemImage: "chevron.right",
                    isDisabled: office.pageCount == 0 || office.currentPage >= office.pageCount,
                    action: { [self] in office.sendNavigate(.nextPage) }
                )
            )
        }
        return items
    }

    private func previewOfficeRichTextToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "office-zoom-out",
                title: L10n.Preview.Toolbar.zoomOut,
                systemImage: "minus.magnifyingglass",
                isDisabled: office.zoomScale <= 0.25,
                action: { [self] in
                    office.zoomScale = max(office.zoomScale / 1.2, 0.25)
                }
            ),
            PreviewToolbarOverflowModel(
                id: "office-scale",
                menuTitle: L10n.Preview.Toolbar.zoomScale,
                menuSystemImage: "percent",
                isDisabled: false,
                estimatedWidth: 44,
                menuAction: {},
                content: AnyView(
                    Text("\(Int((office.zoomScale * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                        .instantHoverTooltip(L10n.Preview.Toolbar.zoomScale)
                )
            ),
            previewToolbarIconItem(
                id: "office-zoom-in",
                title: L10n.Preview.Toolbar.zoomIn,
                systemImage: "plus.magnifyingglass",
                isDisabled: office.zoomScale >= 5.0,
                action: { [self] in
                    office.zoomScale = min(office.zoomScale * 1.2, 5.0)
                }
            ),
            previewToolbarIconItem(
                id: "office-reset",
                title: L10n.Preview.Toolbar.reset,
                systemImage: "arrow.counterclockwise",
                isDisabled: abs(office.zoomScale - 1.0) < 0.001,
                action: { [self] in office.zoomScale = 1.0 }
            ),
        ]
    }
}
