import AppKit
import SceneKit

/// 预览区专用 SceneKit 视图：接管滚轮/捏合缩放、右键平移，并确保可成为 first responder。
final class Model3DSceneView: SCNView {
    private var isRightMousePanning = false

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.modifierFlags.contains(.control), event.buttonNumber == 0 {
            isRightMousePanning = true
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if isRightMousePanning {
            Model3DCameraManipulator.pan(self, deltaX: event.deltaX, deltaY: event.deltaY)
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isRightMousePanning, event.buttonNumber == 0 {
            isRightMousePanning = false
            return
        }
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRightMousePanning = true
    }

    override func rightMouseDragged(with event: NSEvent) {
        Model3DCameraManipulator.pan(self, deltaX: event.deltaX, deltaY: event.deltaY)
    }

    override func rightMouseUp(with event: NSEvent) {
        isRightMousePanning = false
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        nil
    }

    override func scrollWheel(with event: NSEvent) {
        window?.makeFirstResponder(self)

        if event.hasPreciseScrollingDeltas {
            Model3DCameraManipulator.zoomFromScrollDelta(event.scrollingDeltaY, in: self)
        } else {
            let delta = event.deltaY
            guard abs(delta) > 0.01 else { return }
            let factor: Float = delta > 0
                ? Model3DCameraManipulator.scrollZoomInFactor
                : Model3DCameraManipulator.scrollZoomOutFactor
            Model3DCameraManipulator.zoom(self, factor: factor)
        }
    }

    override func magnify(with event: NSEvent) {
        window?.makeFirstResponder(self)
        Model3DCameraManipulator.zoomFromMagnification(event.magnification, in: self)
    }
}
