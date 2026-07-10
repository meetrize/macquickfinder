import AppKit
import FileList
import SwiftUI

extension PreviewSession {
    func previewModel3DToolbarItems(for item: FileItem) -> [PreviewToolbarOverflowModel] {
        guard content.model3DContent != nil else { return [] }

        let isWireframe = model3D.displayMode == .wireframe
        return [
            previewToolbarIconItem(
                id: "model3d-zoom-out",
                title: L10n.Preview.Toolbar.zoomOut,
                systemImage: "minus.magnifyingglass",
                action: { [self] in model3D.sendCameraAction(.zoomOut) }
            ),
            previewToolbarIconItem(
                id: "model3d-zoom-in",
                title: L10n.Preview.Toolbar.zoomIn,
                systemImage: "plus.magnifyingglass",
                action: { [self] in model3D.sendCameraAction(.zoomIn) }
            ),
            previewToolbarIconItem(
                id: "model3d-rotate-left",
                title: L10n.Preview.Toolbar.rotateCCW,
                systemImage: "rotate.left",
                action: { [self] in model3D.sendCameraAction(.rotateLeft) }
            ),
            previewToolbarIconItem(
                id: "model3d-rotate-right",
                title: L10n.Preview.Toolbar.rotateCW,
                systemImage: "rotate.right",
                action: { [self] in model3D.sendCameraAction(.rotateRight) }
            ),
            previewToolbarIconItem(
                id: "model3d-rotate-up",
                title: L10n.Preview.Toolbar.model3dRotateUp,
                systemImage: "arrow.up",
                action: { [self] in model3D.sendCameraAction(.rotateUp) }
            ),
            previewToolbarIconItem(
                id: "model3d-rotate-down",
                title: L10n.Preview.Toolbar.model3dRotateDown,
                systemImage: "arrow.down",
                action: { [self] in model3D.sendCameraAction(.rotateDown) }
            ),
            previewToolbarIconItem(
                id: "model3d-fit",
                title: L10n.Preview.Toolbar.resetView,
                systemImage: "arrow.up.left.and.arrow.down.right",
                action: { [self] in model3D.requestFitFrame() }
            ),
            previewToolbarIconItem(
                id: "model3d-wireframe",
                title: isWireframe
                    ? L10n.Preview.Toolbar.model3dSolid
                    : L10n.Preview.Toolbar.model3dWireframe,
                systemImage: isWireframe ? "cube.fill" : "cube.transparent",
                action: { [self] in model3D.toggleWireframe() }
            ),
            previewToolbarIconItem(
                id: "model3d-copy-info",
                title: L10n.Preview.Toolbar.copyModelInfo,
                systemImage: "doc.on.doc",
                action: { [self] in copyModel3DInfoToPasteboard() }
            ),
            previewToolbarIconItem(
                id: "model3d-open",
                title: L10n.Preview.Toolbar.openDefaultApp,
                systemImage: "arrow.up.forward.app",
                action: { NSWorkspace.shared.open(item.url) }
            ),
        ]
    }

    func copyModel3DInfoToPasteboard() {
        guard let content = content.model3DContent else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content.summaryText, forType: .string)
    }
}
