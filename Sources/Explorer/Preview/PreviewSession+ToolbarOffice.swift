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

    private func previewQuickLookOfficeToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        let ext = item.url.pathExtension.lowercased()
        let showsPageControls = BuiltinPreviewExtensions.presentation.contains(ext) || office.pageCount > 1
        var items: [PreviewToolbarOverflowModel] = []
        if showsPageControls {
            items.append(
                previewToolbarIconItem(
                    id: "office-prev",
                    title: "上一页",
                    systemImage: "chevron.left",
                    isDisabled: office.pageCount > 0 && office.currentPage <= 1,
                    action: { [self] in office.sendNavigate(.previousPage) }
                )
            )
        }
        items.append(contentsOf: [
            previewToolbarIconItem(
                id: "office-zoom-out",
                title: "缩小",
                systemImage: "minus.magnifyingglass",
                isDisabled: office.zoomScale <= 0.25,
                action: { [self] in office.sendNavigate(.zoomOut) }
            ),
            PreviewToolbarOverflowModel(
                id: "office-scale",
                menuTitle: "缩放比例",
                menuSystemImage: "percent",
                isDisabled: false,
                estimatedWidth: 44,
                menuAction: {},
                content: AnyView(
                    Text("\(Int((office.zoomScale * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                        .instantHoverTooltip("缩放比例")
                )
            ),
            previewToolbarIconItem(
                id: "office-zoom-in",
                title: "放大",
                systemImage: "plus.magnifyingglass",
                isDisabled: office.zoomScale >= 5.0,
                action: { [self] in office.sendNavigate(.zoomIn) }
            ),
            previewToolbarIconItem(
                id: "office-reset",
                title: "还原",
                systemImage: "arrow.counterclockwise",
                isDisabled: abs(office.zoomScale - 1.0) < 0.001,
                action: { [self] in office.sendNavigate(.resetZoom) }
            ),
        ])
        if showsPageControls {
            items.append(
                PreviewToolbarOverflowModel(
                    id: "office-page",
                    menuTitle: "页码",
                    menuSystemImage: "number",
                    isDisabled: false,
                    estimatedWidth: 56,
                    menuAction: {},
                    content: AnyView(
                        Text(office.pageCount > 0 ? "\(office.currentPage)/\(office.pageCount)" : "…")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(minWidth: 56, alignment: .center)
                            .instantHoverTooltip("页码")
                    )
                )
            )
            items.append(
                previewToolbarIconItem(
                    id: "office-next",
                    title: "下一页",
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
                title: "缩小",
                systemImage: "minus.magnifyingglass",
                isDisabled: office.zoomScale <= 0.25,
                action: { [self] in
                    office.zoomScale = max(office.zoomScale / 1.2, 0.25)
                }
            ),
            PreviewToolbarOverflowModel(
                id: "office-scale",
                menuTitle: "缩放比例",
                menuSystemImage: "percent",
                isDisabled: false,
                estimatedWidth: 44,
                menuAction: {},
                content: AnyView(
                    Text("\(Int((office.zoomScale * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                        .instantHoverTooltip("缩放比例")
                )
            ),
            previewToolbarIconItem(
                id: "office-zoom-in",
                title: "放大",
                systemImage: "plus.magnifyingglass",
                isDisabled: office.zoomScale >= 5.0,
                action: { [self] in
                    office.zoomScale = min(office.zoomScale * 1.2, 5.0)
                }
            ),
            previewToolbarIconItem(
                id: "office-reset",
                title: "还原",
                systemImage: "arrow.counterclockwise",
                isDisabled: abs(office.zoomScale - 1.0) < 0.001,
                action: { [self] in office.zoomScale = 1.0 }
            ),
        ]
    }
}
