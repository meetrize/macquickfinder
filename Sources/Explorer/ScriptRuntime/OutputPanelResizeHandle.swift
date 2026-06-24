import SwiftUI
import AppKit

/// 输出面板顶部分隔条：拖拽时分隔条顶边跟随鼠标（窗口坐标），松手后持久化高度。
struct OutputPanelResizeHandle: NSViewRepresentable {
    var panelHeight: CGFloat
    var minHeight: CGFloat
    var maxHeight: CGFloat
    var onHeightChange: (CGFloat) -> Void
    var onDragEnded: (CGFloat) -> Void

    func makeNSView(context: Context) -> OutputPanelResizeHandleNSView {
        OutputPanelResizeHandleNSView()
    }

    func updateNSView(_ nsView: OutputPanelResizeHandleNSView, context: Context) {
        context.coordinator.configure(
            panelHeight: panelHeight,
            minHeight: minHeight,
            maxHeight: maxHeight,
            onHeightChange: onHeightChange,
            onDragEnded: onDragEnded,
            view: nsView
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var panelHeight: CGFloat = 200
        private var minHeight: CGFloat = 80
        private var maxHeight: CGFloat = 800
        private var onHeightChange: ((CGFloat) -> Void)?
        private var onDragEnded: ((CGFloat) -> Void)?

        func configure(
            panelHeight: CGFloat,
            minHeight: CGFloat,
            maxHeight: CGFloat,
            onHeightChange: @escaping (CGFloat) -> Void,
            onDragEnded: @escaping (CGFloat) -> Void,
            view: OutputPanelResizeHandleNSView
        ) {
            self.panelHeight = panelHeight
            self.minHeight = minHeight
            self.maxHeight = maxHeight
            self.onHeightChange = onHeightChange
            self.onDragEnded = onDragEnded

            view.minHeight = minHeight
            view.onDragStart = { [weak self] windowMouseY in
                guard let self else { return }
                self.maxHeight = Self.resolvedMaxHeight(requested: maxHeight, in: view.window)
                view.dragStartMouseYWindow = windowMouseY
                view.dragStartPanelHeight = self.panelHeight
            }
            view.onDragChange = { [weak self] windowMouseY in
                guard let self, let startY = view.dragStartMouseYWindow else { return }
                let startHeight = view.dragStartPanelHeight ?? self.panelHeight
                let delta = windowMouseY - startY
                let clamped = min(max(startHeight + delta, self.minHeight), self.maxHeight)
                self.onHeightChange?(clamped)
            }
            view.onDragEnd = { [weak self] windowMouseY in
                guard let self, let startY = view.dragStartMouseYWindow else { return }
                let startHeight = view.dragStartPanelHeight ?? self.panelHeight
                let delta = windowMouseY - startY
                let clamped = min(max(startHeight + delta, self.minHeight), self.maxHeight)
                self.onDragEnded?(clamped)
                view.dragStartMouseYWindow = nil
                view.dragStartPanelHeight = nil
            }
        }

        private static func resolvedMaxHeight(requested: CGFloat, in window: NSWindow?) -> CGFloat {
            guard let contentHeight = window?.contentView?.bounds.height, contentHeight > 0 else {
                return requested
            }
            return min(requested, OutputPanelMetrics.maxPanelHeight(forContainerHeight: contentHeight))
        }
    }
}

final class OutputPanelResizeHandleNSView: NSView {
    var minHeight: CGFloat = 80
    var onDragStart: ((CGFloat) -> Void)?
    var onDragChange: ((CGFloat) -> Void)?
    var onDragEnd: ((CGFloat) -> Void)?

    var dragStartMouseYWindow: CGFloat?
    var dragStartPanelHeight: CGFloat?

    /// 可点击/拖拽的命中区域（大于视觉高度）
    private var hitHeight: CGFloat { OutputPanelMetrics.resizeHandleHitHeight }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let expanded = bounds.insetBy(dx: 0, dy: -(hitHeight - bounds.height) / 2)
        return expanded.contains(point) ? self : nil
    }

    override func resetCursorRects() {
        discardCursorRects()
        let expanded = bounds.insetBy(dx: 0, dy: -(hitHeight - bounds.height) / 2)
        addCursorRect(expanded, cursor: .resizeUpDown)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner as AnyObject === self {
            removeTrackingArea(area)
        }
        let expanded = bounds.insetBy(dx: 0, dy: -(hitHeight - bounds.height) / 2)
        let area = NSTrackingArea(
            rect: expanded,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeUpDown.set()
    }

    override func mouseDown(with event: NSEvent) {
        let windowY = event.locationInWindow.y
        dragStartMouseYWindow = windowY
        onDragStart?(windowY)
    }

    override func mouseDragged(with event: NSEvent) {
        onDragChange?(event.locationInWindow.y)
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?(event.locationInWindow.y)
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height).fill()
    }
}
