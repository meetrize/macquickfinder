import AppKit
import SwiftUI

/// 双栏中间分隔条：按鼠标位移增量改比例（与侧栏 / 预览分隔条一致），双击均分。
struct DualPaneSplitDivider: NSViewRepresentable {
    @Binding var splitRatio: Double
    /// 用于把像素位移换算成比例的可用宽度（总宽 − 分隔条命中宽）。
    var containerWidth: CGFloat
    var minRatio: Double = 0.2
    var maxRatio: Double = 0.8
    var onDragEnded: (() -> Void)?
    var onDoubleClickEqualize: (() -> Void)?

    func makeNSView(context: Context) -> DualPaneSplitDividerNSView {
        let view = DualPaneSplitDividerNSView()
        context.coordinator.apply(to: view)
        return view
    }

    func updateNSView(_ nsView: DualPaneSplitDividerNSView, context: Context) {
        context.coordinator.splitRatio = $splitRatio
        context.coordinator.containerWidth = containerWidth
        context.coordinator.minRatio = minRatio
        context.coordinator.maxRatio = maxRatio
        context.coordinator.onDragEnded = onDragEnded
        context.coordinator.onDoubleClickEqualize = onDoubleClickEqualize
        context.coordinator.apply(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var splitRatio: Binding<Double> = .constant(0.5)
        var containerWidth: CGFloat = 1
        var minRatio: Double = 0.2
        var maxRatio: Double = 0.8
        var onDragEnded: (() -> Void)?
        var onDoubleClickEqualize: (() -> Void)?

        func apply(to view: DualPaneSplitDividerNSView) {
            view.onDelta = { [weak self] delta in
                guard let self else { return }
                let width = max(self.containerWidth, 1)
                let next = self.splitRatio.wrappedValue + Double(delta / width)
                self.splitRatio.wrappedValue = min(max(next, self.minRatio), self.maxRatio)
            }
            view.onDragEnded = onDragEnded
            view.onDoubleClickEqualize = onDoubleClickEqualize
        }
    }
}

final class DualPaneSplitDividerNSView: NSView {
    var onDelta: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    var onDoubleClickEqualize: (() -> Void)?

    private var lastMouseX: CGFloat?
    private var isHovered = false
    private var isDragging = false
    private var tracking: NSTrackingArea?

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            isHovered = false
            needsDisplay = true
            NSCursor.arrow.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            onDoubleClickEqualize?()
            return
        }
        lastMouseX = event.locationInWindow.x
        isDragging = true
        isHovered = true
        needsDisplay = true
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let lastX = lastMouseX else { return }
        let currentX = event.locationInWindow.x
        let delta = currentX - lastX
        lastMouseX = currentX
        NSCursor.resizeLeftRight.set()
        // 忽略亚像素抖动，减少无意义的 SwiftUI 刷新。
        guard abs(delta) >= 0.5 else { return }
        onDelta?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        lastMouseX = nil
        isDragging = false
        let stillInside = bounds.contains(convert(event.locationInWindow, from: nil))
        isHovered = stillInside
        needsDisplay = true
        if stillInside {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.arrow.set()
        }
        onDragEnded?()
    }

    override func draw(_ dirtyRect: NSRect) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let idleThickness = PanelSeparatorStyle.hairlineThickness(for: scale)
        let thickness = (isHovered || isDragging)
            ? PanelResizeHandleMetrics.hoverThickness
            : idleThickness
        let lineX = floor((bounds.width - thickness) / 2 * scale) / scale
        let lineRect = NSRect(x: lineX, y: bounds.minY, width: thickness, height: bounds.height)
        PanelSeparatorStyle.fill(dirtyRect.intersection(lineRect), in: self)
    }
}
