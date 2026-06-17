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
            return min(requested, contentHeight * 0.85)
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

    /// 视觉分隔线高度
    private let lineThickness: CGFloat = 1
    /// 可点击/拖拽的命中区域（大于视觉线宽）
    private let hitHeight: CGFloat = 14

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let expanded = bounds.insetBy(dx: 0, dy: -(hitHeight - lineThickness) / 2)
        return expanded.contains(point) ? self : nil
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner as AnyObject === self {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
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

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        let lineY = floor((bounds.height - lineThickness) / 2)
        NSRect(x: 0, y: lineY, width: bounds.width, height: lineThickness).fill()
    }
}
