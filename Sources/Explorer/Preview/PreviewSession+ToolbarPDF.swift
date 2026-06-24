import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewPDFToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "pdf-prev",
                title: L10n.Preview.Toolbar.previousPage,
                systemImage: "chevron.left",
                isDisabled: pdf.currentPage <= 1,
                action: { [self] in pdf.navigateAction = .previous }
            ),
            previewToolbarIconItem(
                id: "pdf-zoom-out",
                title: L10n.Preview.Toolbar.zoomOut,
                systemImage: "minus.magnifyingglass",
                isDisabled: pdf.scalePercent > 0 && pdf.scalePercent <= 25,
                action: { [self] in pdf.navigateAction = .zoomOut }
            ),
            PreviewToolbarOverflowModel(
                id: "pdf-page",
                menuTitle: L10n.Preview.Toolbar.pageNumber,
                menuSystemImage: "number",
                isDisabled: false,
                estimatedWidth: 82,
                menuAction: {},
                content: AnyView(PreviewPDFPageInputField(session: self))
            ),
            PreviewToolbarOverflowModel(
                id: "pdf-scale",
                menuTitle: L10n.Preview.Toolbar.zoomScale,
                menuSystemImage: "percent",
                isDisabled: false,
                estimatedWidth: 44,
                menuAction: {},
                content: AnyView(
                    Text(pdf.scalePercent > 0 ? "\(pdf.scalePercent)%" : "--")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                        .instantHoverTooltip(L10n.Preview.Toolbar.zoomScale)
                )
            ),
            previewToolbarIconItem(
                id: "pdf-zoom-in",
                title: L10n.Preview.Toolbar.zoomIn,
                systemImage: "plus.magnifyingglass",
                isDisabled: pdf.scalePercent >= 500,
                action: { [self] in pdf.navigateAction = .zoomIn }
            ),
            previewToolbarIconItem(
                id: "pdf-fit-width",
                title: L10n.Preview.Toolbar.fitWidth,
                systemImage: "arrow.left.and.right.square",
                action: { [self] in pdf.navigateAction = .fitWidth }
            ),
            previewToolbarIconItem(
                id: "pdf-fit-page",
                title: L10n.Preview.Toolbar.fitPage,
                systemImage: "arrow.up.left.and.arrow.down.right",
                action: { [self] in pdf.navigateAction = .fitPage }
            ),
            previewToolbarIconItem(
                id: "pdf-next",
                title: L10n.Preview.Toolbar.nextPage,
                systemImage: "chevron.right",
                isDisabled: pdf.pageCount == 0 || pdf.currentPage >= pdf.pageCount,
                action: { [self] in pdf.navigateAction = .next }
            ),
        ]
    }
}
