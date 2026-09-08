import SwiftUI
import AppKit

/// 预览 / Snippets / Git 之间的垂直分隔条：拖拽时按窗口坐标改高度，松手后持久化。
struct VerticalResizeDivider: NSViewRepresentable {
    var previewHeight: CGFloat
    var totalHeight: CGFloat
    var minTopHeight: CGFloat
    var minBottomHeight: CGFloat
    var onHeightChange: (CGFloat) -> Void
    var onDragEnded: (CGFloat) -> Void

    func makeNSView(context: Context) -> VerticalResizeDividerNSView {
        VerticalResizeDividerNSView()
    }

    func updateNSView(_ nsView: VerticalResizeDividerNSView, context: Context) {
        context.coordinator.configure(
            previewHeight: previewHeight,
            totalHeight: totalHeight,
            minTopHeight: minTopHeight,
            minBottomHeight: minBottomHeight,
            onHeightChange: onHeightChange,
            onDragEnded: onDragEnded,
            view: nsView
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var previewHeight: CGFloat = 200
        private var totalHeight: CGFloat = 400
        private var minTopHeight: CGFloat = 80
        private var minBottomHeight: CGFloat = 80
        private var onHeightChange: ((CGFloat) -> Void)?
        private var onDragEnded: ((CGFloat) -> Void)?

        func configure(
            previewHeight: CGFloat,
            totalHeight: CGFloat,
            minTopHeight: CGFloat,
            minBottomHeight: CGFloat,
            onHeightChange: @escaping (CGFloat) -> Void,
            onDragEnded: @escaping (CGFloat) -> Void,
            view: VerticalResizeDividerNSView
        ) {
            self.previewHeight = previewHeight
            self.totalHeight = totalHeight
            self.minTopHeight = minTopHeight
            self.minBottomHeight = minBottomHeight
            self.onHeightChange = onHeightChange
            self.onDragEnded = onDragEnded

            view.minTopHeight = minTopHeight
            view.minBottomHeight = minBottomHeight
            view.dividerThickness = VerticalResizeDividerMetrics.visualHeight

            view.onDragStart = { [weak self] windowMouseY in
                guard let self else { return }
                view.dragStartMouseYWindow = windowMouseY
                view.dragStartPreviewHeight = self.previewHeight
                view.dragStartTotalHeight = self.totalHeight
            }
            view.onDragChange = { [weak self] windowMouseY in
                guard let self, let startY = view.dragStartMouseYWindow else { return }
                let startHeight = view.dragStartPreviewHeight ?? self.previewHeight
                let total = view.dragStartTotalHeight ?? self.totalHeight
                let clamped = Self.clampedPreviewHeight(
                    startHeight + (startY - windowMouseY),
                    totalHeight: total,
                    minTopHeight: self.minTopHeight,
                    minBottomHeight: self.minBottomHeight,
                    dividerThickness: VerticalResizeDividerMetrics.visualHeight
                )
                self.onHeightChange?(clamped)
            }
            view.onDragEnd = { [weak self] windowMouseY in
                guard let self, let startY = view.dragStartMouseYWindow else { return }
                let startHeight = view.dragStartPreviewHeight ?? self.previewHeight
                let total = view.dragStartTotalHeight ?? self.totalHeight
                let clamped = Self.clampedPreviewHeight(
                    startHeight + (startY - windowMouseY),
                    totalHeight: total,
                    minTopHeight: self.minTopHeight,
                    minBottomHeight: self.minBottomHeight,
                    dividerThickness: VerticalResizeDividerMetrics.visualHeight
                )
                self.onDragEnded?(clamped)
                view.dragStartMouseYWindow = nil
                view.dragStartPreviewHeight = nil
                view.dragStartTotalHeight = nil
            }
        }

        private static func clampedPreviewHeight(
            _ height: CGFloat,
            totalHeight: CGFloat,
            minTopHeight: CGFloat,
            minBottomHeight: CGFloat,
            dividerThickness: CGFloat
        ) -> CGFloat {
            guard totalHeight > 0 else { return minTopHeight }
            let maxTop = max(minTopHeight, totalHeight - minBottomHeight - dividerThickness)
            return min(max(height, minTopHeight), maxTop)
        }
    }
}

enum VerticalResizeDividerMetrics {
    static let visualHeight: CGFloat = PanelResizeHandleMetrics.visualExtent
    static let hitHeight: CGFloat = PanelResizeHandleMetrics.hitExtent
    static let hoverThickness: CGFloat = PanelResizeHandleMetrics.hoverThickness
}

extension View {
    /// 布局只占 `visualHeight`，命中区居中溢出并压在邻面板之上。
    func verticalResizeDividerChrome() -> some View {
        frame(height: VerticalResizeDividerMetrics.hitHeight)
            .padding(
                .vertical,
                -(VerticalResizeDividerMetrics.hitHeight - VerticalResizeDividerMetrics.visualHeight) / 2
            )
            .zIndex(1)
    }
}

final class VerticalResizeDividerNSView: NSView {
    var minTopHeight: CGFloat = 80
    var minBottomHeight: CGFloat = 80
    var dividerThickness: CGFloat = VerticalResizeDividerMetrics.visualHeight

    var onDragStart: ((CGFloat) -> Void)?
    var onDragChange: ((CGFloat) -> Void)?
    var onDragEnd: ((CGFloat) -> Void)?

    var dragStartMouseYWindow: CGFloat?
    var dragStartPreviewHeight: CGFloat?
    var dragStartTotalHeight: CGFloat?

    private var isHovered = false
    private var isDragging = false

    /// 叠在邻面板上时上下必须透明，否则会盖住预览/Snippets/Git 内容。
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
            ? VerticalResizeDividerMetrics.hoverThickness
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
