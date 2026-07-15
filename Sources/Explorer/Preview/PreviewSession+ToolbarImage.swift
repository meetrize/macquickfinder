import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewQuickLookImageToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        [
            previewToolbarIconItem(
                id: "quicklook-image-zoom-out",
                title: L10n.Preview.Toolbar.zoomOut,
                systemImage: "minus.magnifyingglass",
                isDisabled: office.zoomScale <= 0.25,
                action: { [self] in office.sendNavigate(.zoomOut) }
            ),
            PreviewToolbarOverflowModel(
                id: "quicklook-image-scale",
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
                id: "quicklook-image-zoom-in",
                title: L10n.Preview.Toolbar.zoomIn,
                systemImage: "plus.magnifyingglass",
                isDisabled: office.zoomScale >= 5.0,
                action: { [self] in office.sendNavigate(.zoomIn) }
            ),
            previewToolbarIconItem(
                id: "quicklook-image-reset",
                title: L10n.Preview.Toolbar.reset,
                systemImage: "arrow.counterclockwise",
                isDisabled: abs(office.zoomScale - 1.0) < 0.001,
                action: { [self] in office.sendNavigate(.resetZoom) }
            ),
            previewToolbarIconItem(
                id: "quicklook-image-copy",
                title: L10n.Preview.Toolbar.copyImage,
                systemImage: "doc.on.doc",
                action: { [self] in copyImageToPasteboard(item) }
            ),
        ]
    }

    func previewImageToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        var items: [PreviewToolbarOverflowModel] = [
            PreviewToolbarOverflowModel(
                id: "image-zoom",
                menuTitle: L10n.Preview.Toolbar.zoom,
                menuSystemImage: "plus.magnifyingglass",
                isDisabled: false,
                estimatedWidth: 120,
                menuAction: {},
                content: AnyView(PreviewImageZoomToolbarControls(session: self))
            ),
            previewToolbarIconItem(
                id: "image-rotate-left",
                title: L10n.Preview.Toolbar.rotateCCW,
                systemImage: "rotate.left",
                isDisabled: image.isCropping,
                action: { [self] in
                    performImageEdit { [self] in
                        self.image.rotationQuarterTurns = (self.image.rotationQuarterTurns + 3) % 4
                        self.image.cropRectNormalized = nil
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-rotate-right",
                title: L10n.Preview.Toolbar.rotateCW,
                systemImage: "rotate.right",
                isDisabled: image.isCropping,
                action: { [self] in
                    performImageEdit { [self] in
                        self.image.rotationQuarterTurns = (self.image.rotationQuarterTurns + 1) % 4
                        self.image.cropRectNormalized = nil
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-flip-horizontal",
                title: L10n.Preview.Toolbar.flipHorizontal,
                systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                isDisabled: image.isCropping,
                action: { [self] in
                    performImageEdit { [self] in
                        self.image.flipHorizontal.toggle()
                        self.image.cropRectNormalized = nil
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-flip-vertical",
                title: L10n.Preview.Toolbar.flipVertical,
                systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                isDisabled: image.isCropping,
                action: { [self] in
                    performImageEdit { [self] in
                        self.image.flipVertical.toggle()
                        self.image.cropRectNormalized = nil
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-crop",
                title: image.isCropping ? L10n.Preview.Toolbar.applyCrop : L10n.Preview.Toolbar.crop,
                systemImage: image.isCropping ? "checkmark.rectangle" : "crop",
                isDisabled: image.sourcePixelSize.width <= 0 || image.sourcePixelSize.height <= 0,
                action: { [self] in
                    if self.image.isCropping {
                        // applyCropDraft 内部已 pushUndo；此处只负责升到全分辨率。
                        Task { [self] in
                            await self.upgradeImageToFullResolutionIfNeeded()
                            await MainActor.run {
                                self.image.applyCropDraft()
                            }
                        }
                    } else {
                        self.image.beginCropping()
                    }
                }
            ),
            previewToolbarIconItem(
                id: "image-undo",
                title: L10n.Preview.Toolbar.undo,
                systemImage: "arrow.uturn.backward",
                isDisabled: image.editUndoStack.isEmpty,
                action: { [self] in image.undoLastEdit() }
            ),
            previewToolbarIconItem(
                id: "image-reset",
                title: L10n.Preview.Toolbar.resetView,
                systemImage: "arrow.counterclockwise",
                action: { [self] in image.resetViewTransform() }
            ),
            previewToolbarIconItem(
                id: "image-resize",
                title: L10n.Preview.Toolbar.resize,
                systemImage: "rectangle.and.arrow.up.right.and.arrow.down.left",
                isDisabled: image.isCropping
                    || image.sourcePixelSize.width <= 0
                    || image.sourcePixelSize.height <= 0,
                action: { [self] in
                    self.image.isCropping = false
                    self.image.cropDraftNormalized = nil
                    self.image.showResizeSheet = true
                }
            ),
            previewToolbarIconItem(
                id: "image-save",
                title: L10n.Preview.Toolbar.saveEdits,
                systemImage: "square.and.arrow.down",
                isDisabled: !image.hasEdits,
                action: { [self] in image.previewAction = .save }
            ),
            PreviewToolbarOverflowModel(
                id: "image-eyedropper",
                menuTitle: L10n.Preview.Toolbar.eyedropper,
                menuSystemImage: "eyedropper",
                isDisabled: false,
                estimatedWidth: 20,
                menuAction: { [self] in image.eyedropperActive.toggle() },
                content: AnyView(PreviewImageEyedropperToolbarButton(session: self))
            ),
            previewToolbarIconItem(
                id: "image-copy",
                title: L10n.Preview.Toolbar.copyImage,
                systemImage: "doc.on.doc",
                action: { [self] in copyImageToPasteboard(item) }
            ),
        ]

        if let hex = image.pickedWebColor {
            items.insert(
                PreviewToolbarOverflowModel(
                    id: "image-color",
                    menuTitle: L10n.Preview.Toolbar.colorHex(hex),
                    menuSystemImage: "eyedropper.half.filled",
                    isDisabled: false,
                    estimatedWidth: 72,
                    menuAction: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hex, forType: .string)
                    },
                    content: AnyView(PreviewImageColorSwatch(hex: hex, session: self))
                ),
                at: items.count - 1
            )
        }

        return items
    }
}
