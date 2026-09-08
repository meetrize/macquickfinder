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

    private var isHovered = false
    private var isDragging = false

    /// 叠在主内容上时上下必须透明。
    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeUpDown.set()
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
        NSCursor.resizeUpDown.set()
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            setHovered(false)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let windowY = event.locationInWindow.y
        dragStartMouseYWindow = windowY
        isDragging = true
        setHovered(true)
        NSCursor.resizeUpDown.set()
        onDragStart?(windowY)
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.resizeUpDown.set()
        onDragChange?(event.locationInWindow.y)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        let stillInside = bounds.contains(convert(event.locationInWindow, from: nil))
        setHovered(stillInside)
        if stillInside {
            NSCursor.resizeUpDown.set()
        }
        onDragEnd?(event.locationInWindow.y)
    }

    override func draw(_ dirtyRect: NSRect) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let idleThickness = PanelSeparatorStyle.hairlineThickness(for: scale)
        let thickness = (isHovered || isDragging)
            ? PanelResizeHandleMetrics.hoverThickness
            : idleThickness
        let lineY = floor((bounds.height - thickness) / 2 * scale) / scale
        let lineRect = NSRect(x: bounds.minX, y: lineY, width: bounds.width, height: thickness)
        PanelSeparatorStyle.fill(dirtyRect.intersection(lineRect), in: self)
    }

    private func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        needsDisplay = true
    }
}
