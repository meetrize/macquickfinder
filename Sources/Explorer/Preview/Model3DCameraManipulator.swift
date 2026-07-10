import SceneKit
import simd

enum Model3DCameraManipulator {
    static let zoomInFactor: Float = 0.82
    static let zoomOutFactor: Float = 1.22
    static let rotateYawStep: Float = .pi / 12
    static let rotatePitchStep: Float = .pi / 18
    static let scrollZoomInFactor: Float = 0.92
    static let scrollZoomOutFactor: Float = 1.08

    static func apply(_ action: PreviewSessionModel3DState.CameraAction, to view: SCNView) {
        switch action {
        case .zoomIn:
            zoom(view, factor: zoomInFactor)
        case .zoomOut:
            zoom(view, factor: zoomOutFactor)
        case .rotateLeft:
            rotate(view, yawRadians: rotateYawStep, pitchRadians: 0)
        case .rotateRight:
            rotate(view, yawRadians: -rotateYawStep, pitchRadians: 0)
        case .rotateUp:
            rotate(view, yawRadians: 0, pitchRadians: rotatePitchStep)
        case .rotateDown:
            rotate(view, yawRadians: 0, pitchRadians: -rotatePitchStep)
        }
    }

    static func zoomFromScrollDelta(_ deltaY: CGFloat, in view: SCNView) {
        guard abs(deltaY) > 0.01 else { return }
        let factor = deltaY > 0 ? scrollZoomInFactor : scrollZoomOutFactor
        zoom(view, factor: factor)
    }

    static func zoomFromMagnification(_ magnification: CGFloat, in view: SCNView) {
        guard abs(magnification) > 0.0001 else { return }
        let factor = Float(max(0.4, min(2.5, 1.0 - magnification)))
        zoom(view, factor: factor)
    }

    static func pan(_ view: SCNView, deltaX: CGFloat, deltaY: CGFloat) {
        guard let camera = view.pointOfView else { return }
        guard abs(deltaX) > 0.01 || abs(deltaY) > 0.01 else { return }

        let target = simdTarget(view.defaultCameraController.target)
        let distance = simd_length(camera.simdWorldPosition - target)
        guard distance > 1e-4 else { return }

        let sensitivity = distance * 0.0015
        let right = camera.simdWorldRight
        let up = camera.simdWorldUp
        let translation = right * Float(-deltaX) * sensitivity + up * Float(deltaY) * sensitivity

        let newTarget = target + translation
        camera.simdWorldPosition += translation
        view.defaultCameraController.target = scnVector(newTarget)
        camera.look(at: view.defaultCameraController.target)
    }

    static func zoom(_ view: SCNView, factor: Float) {
        guard let camera = view.pointOfView else { return }
        let target = simdTarget(view.defaultCameraController.target)
        var offset = camera.simdWorldPosition - target
        let length = simd_length(offset)
        guard length > 1e-4 else { return }

        let minDistance: Float = 0.05
        let maxDistance: Float = 10_000
        let newLength = min(max(length * factor, minDistance), maxDistance)
        offset = simd_normalize(offset) * newLength
        camera.simdWorldPosition = target + offset
        camera.look(at: view.defaultCameraController.target)
    }

    static func rotate(_ view: SCNView, yawRadians: Float, pitchRadians: Float) {
        guard let camera = view.pointOfView else { return }
        let target = simdTarget(view.defaultCameraController.target)
        var offset = camera.simdWorldPosition - target
        guard simd_length(offset) > 1e-4 else { return }

        if abs(yawRadians) > 0 {
            let yawRotation = simd_quatf(angle: yawRadians, axis: SIMD3<Float>(0, 1, 0))
            offset = simd_act(yawRotation, offset)
        }

        if abs(pitchRadians) > 0 {
            let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), offset))
            if simd_length(right) > 1e-4 {
                let pitchRotation = simd_quatf(angle: pitchRadians, axis: right)
                offset = simd_act(pitchRotation, offset)
            }
        }

        camera.simdWorldPosition = target + offset
        camera.look(at: view.defaultCameraController.target)
    }

    private static func simdTarget(_ target: SCNVector3) -> SIMD3<Float> {
        SIMD3<Float>(Float(target.x), Float(target.y), Float(target.z))
    }

    private static func scnVector(_ vector: SIMD3<Float>) -> SCNVector3 {
        SCNVector3(vector.x, vector.y, vector.z)
    }
}
