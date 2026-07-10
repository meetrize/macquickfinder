import AppKit
import SceneKit
import SwiftUI

struct Model3DPreviewView: View {
    @ObservedObject var session: PreviewSession
    let content: Model3DPreviewContent

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Model3DSceneRepresentable(
                content: content,
                displayMode: session.model3D.displayMode,
                fitFrameToken: session.model3D.fitFrameToken,
                cameraActionToken: session.model3D.cameraActionToken,
                cameraAction: session.model3D.pendingCameraAction
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            metadataOverlay
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var metadataOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Preview.Model3D.triangles(content.metadata.triangleCount))
                .font(.caption.monospacedDigit())
            Text(L10n.Preview.Model3D.dimensions(
                content.metadata.boundingBoxSize.x,
                content.metadata.boundingBoxSize.y,
                content.metadata.boundingBoxSize.z
            ))
            .font(.caption.monospacedDigit())
            Text(L10n.Preview.Model3D.unitHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .allowsHitTesting(false)
    }
}

private struct Model3DSceneRepresentable: NSViewRepresentable {
    let content: Model3DPreviewContent
    let displayMode: PreviewSessionModel3DState.DisplayMode
    let fitFrameToken: UInt
    let cameraActionToken: UInt
    let cameraAction: PreviewSessionModel3DState.CameraAction?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> Model3DSceneView {
        let view = Model3DSceneView()
        view.backgroundColor = NSColor(srgbRed: 0.68, green: 0.72, blue: 0.78, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        view.defaultCameraController.inertiaFriction = 0.12
        return view
    }

    func updateNSView(_ view: Model3DSceneView, context: Context) {
        let wireframe = displayMode == .wireframe

        if context.coordinator.loadedPath != content.sourcePath {
            context.coordinator.loadedPath = content.sourcePath
            context.coordinator.appliedWireframe = wireframe
            context.coordinator.lastFitFrameToken = fitFrameToken

            let scene = Model3DEnvironmentBuilder.makeStudioScene(
                from: content.sourceURL,
                boundingSize: content.metadata.boundingBoxSize,
                wireframe: wireframe
            )
            view.scene = scene
            frameModel(in: view)
            return
        }

        if context.coordinator.appliedWireframe != wireframe {
            context.coordinator.appliedWireframe = wireframe
            if let modelRoot = Model3DEnvironmentBuilder.modelRoot(in: view.scene) {
                Model3DEnvironmentBuilder.applyPreviewMaterials(to: modelRoot, wireframe: wireframe)
            }
            Model3DEnvironmentBuilder.setGroundGridVisible(!wireframe, in: view.scene)
        }

        if context.coordinator.lastFitFrameToken != fitFrameToken {
            context.coordinator.lastFitFrameToken = fitFrameToken
            frameModel(in: view)
        }

        if context.coordinator.lastCameraActionToken != cameraActionToken,
           let action = cameraAction {
            context.coordinator.lastCameraActionToken = cameraActionToken
            Model3DCameraManipulator.apply(action, to: view)
        }
    }

    private func frameModel(in view: Model3DSceneView) {
        guard let modelRoot = Model3DEnvironmentBuilder.modelRoot(in: view.scene) else { return }
        DispatchQueue.main.async {
            view.defaultCameraController.frameNodes([modelRoot])
        }
    }

    final class Coordinator {
        var loadedPath: String?
        var appliedWireframe = false
        var lastFitFrameToken: UInt = 0
        var lastCameraActionToken: UInt = 0
    }
}
