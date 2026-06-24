import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewPDFToolbarItems() -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "pdf-prev",
                title: "上一页",
                systemImage: "chevron.left",
                isDisabled: pdf.currentPage <= 1,
                action: { [self] in pdf.navigateAction = .previous }
            ),
            previewToolbarIconItem(
                id: "pdf-zoom-out",
                title: "缩小",
                systemImage: "minus.magnifyingglass",
                isDisabled: pdf.scalePercent > 0 && pdf.scalePercent <= 25,
                action: { [self] in pdf.navigateAction = .zoomOut }
            ),
            PreviewToolbarOverflowModel(
                id: "pdf-page",
                menuTitle: "页码",
                menuSystemImage: "number",
                isDisabled: false,
                estimatedWidth: 82,
                menuAction: {},
                content: AnyView(PreviewPDFPageInputField(session: self))
            ),
            PreviewToolbarOverflowModel(
                id: "pdf-scale",
                menuTitle: "缩放比例",
                menuSystemImage: "percent",
                isDisabled: false,
                estimatedWidth: 44,
                menuAction: {},
                content: AnyView(
                    Text(pdf.scalePercent > 0 ? "\(pdf.scalePercent)%" : "--")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                        .instantHoverTooltip("缩放比例")
                )
            ),
            previewToolbarIconItem(
                id: "pdf-zoom-in",
                title: "放大",
                systemImage: "plus.magnifyingglass",
                isDisabled: pdf.scalePercent >= 500,
                action: { [self] in pdf.navigateAction = .zoomIn }
            ),
            previewToolbarIconItem(
                id: "pdf-fit-width",
                title: "适配宽度",
                systemImage: "arrow.left.and.right.square",
                action: { [self] in pdf.navigateAction = .fitWidth }
            ),
            previewToolbarIconItem(
                id: "pdf-fit-page",
                title: "整页适配",
                systemImage: "arrow.up.left.and.arrow.down.right",
                action: { [self] in pdf.navigateAction = .fitPage }
            ),
            previewToolbarIconItem(
                id: "pdf-next",
                title: "下一页",
                systemImage: "chevron.right",
                isDisabled: pdf.pageCount == 0 || pdf.currentPage >= pdf.pageCount,
                action: { [self] in pdf.navigateAction = .next }
            ),
        ]
    }
}
