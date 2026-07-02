import SwiftUI
import AppKit

/// 预览与 Snippets 之间的垂直分隔条：拖拽时分隔条跟随鼠标（窗口坐标），松手后持久化比例。
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
    static let visualHeight: CGFloat = 1
    static let hitHeight: CGFloat = 6
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

    override var isOpaque: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let expanded = bounds.insetBy(dx: 0, dy: -(VerticalResizeDividerMetrics.hitHeight - dividerThickness) / 2)
        return expanded.contains(point) ? self : nil
    }

    override func resetCursorRects() {
        discardCursorRects()
        let expanded = bounds.insetBy(dx: 0, dy: -(VerticalResizeDividerMetrics.hitHeight - dividerThickness) / 2)
        addCursorRect(expanded, cursor: .resizeUpDown)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner as AnyObject === self {
            removeTrackingArea(area)
        }
        let expanded = bounds.insetBy(dx: 0, dy: -(VerticalResizeDividerMetrics.hitHeight - dividerThickness) / 2)
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
        PanelSeparatorStyle.fill(dirtyRect.intersection(bounds), in: self)
    }
}
