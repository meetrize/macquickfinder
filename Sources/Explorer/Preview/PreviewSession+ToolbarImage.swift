import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewImageToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        var items: [PreviewToolbarOverflowModel] = [
            PreviewToolbarOverflowModel(
                id: "image-zoom",
                menuTitle: "缩放",
                menuSystemImage: "plus.magnifyingglass",
                isDisabled: false,
                estimatedWidth: 120,
                menuAction: {},
                content: AnyView(PreviewImageZoomToolbarControls(session: self))
            ),
            previewToolbarIconItem(
                id: "image-rotate-left",
                title: "逆时针旋转",
                systemImage: "rotate.left",
                action: { [self] in
                    image.performEdit {
                        image.rotationQuarterTurns = (image.rotationQuarterTurns + 3) % 4
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-rotate-right",
                title: "顺时针旋转",
                systemImage: "rotate.right",
                action: { [self] in
                    image.performEdit {
                        image.rotationQuarterTurns = (image.rotationQuarterTurns + 1) % 4
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-flip-horizontal",
                title: "水平翻转",
                systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                action: { [self] in
                    image.performEdit {
                        image.flipHorizontal.toggle()
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-flip-vertical",
                title: "垂直翻转",
                systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                action: { [self] in
                    image.performEdit {
                        image.flipVertical.toggle()
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-undo",
                title: "撤销上一步",
                systemImage: "arrow.uturn.backward",
                isDisabled: image.editUndoStack.isEmpty,
                action: { [self] in image.undoLastEdit() }
            ),
            previewToolbarIconItem(
                id: "image-reset",
                title: "重置视图",
                systemImage: "arrow.counterclockwise",
                action: { [self] in image.resetViewTransform() }
            ),
            previewToolbarIconItem(
                id: "image-resize",
                title: "调整尺寸",
                systemImage: "aspectratio",
                isDisabled: image.sourcePixelSize.width <= 0 || image.sourcePixelSize.height <= 0,
                action: { [self] in image.showResizeSheet = true }
            ),
            previewToolbarIconItem(
                id: "image-save",
                title: "保存编辑结果",
                systemImage: "square.and.arrow.down",
                isDisabled: !image.hasEdits,
                action: { [self] in image.previewAction = .save }
            ),
            PreviewToolbarOverflowModel(
                id: "image-eyedropper",
                menuTitle: "取色棒",
                menuSystemImage: "eyedropper",
                isDisabled: false,
                estimatedWidth: 20,
                menuAction: { [self] in image.eyedropperActive.toggle() },
                content: AnyView(PreviewImageEyedropperToolbarButton(session: self))
            ),
            previewToolbarIconItem(
                id: "image-copy",
                title: "复制图片",
                systemImage: "doc.on.doc",
                action: { [self] in copyImageToPasteboard(item) }
            ),
            previewToolbarIconItem(
                id: "image-open",
                title: "用默认应用打开",
                systemImage: "arrow.up.forward.app",
                action: { NSWorkspace.shared.open(item.url) }
            ),
        ]

        if let hex = image.pickedWebColor {
            items.insert(
                PreviewToolbarOverflowModel(
                    id: "image-color",
                    menuTitle: "颜色 \(hex)",
                    menuSystemImage: "eyedropper.half.filled",
                    isDisabled: false,
                    estimatedWidth: 72,
                    menuAction: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hex, forType: .string)
                    },
                    content: AnyView(PreviewImageColorSwatch(hex: hex, session: self))
                ),
                at: items.count - 2
            )
        }

        return items
    }
}
