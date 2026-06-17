import SwiftUI
import AppKit

struct VerticalResizeDivider: NSViewRepresentable {
    @Binding var topRatio: Double
    var minTopHeight: CGFloat = 80
    var minBottomHeight: CGFloat = 80

    func makeNSView(context: Context) -> VerticalResizeDividerNSView {
        VerticalResizeDividerNSView()
    }

    func updateNSView(_ nsView: VerticalResizeDividerNSView, context: Context) {
        context.coordinator.configure(
            topRatio: $topRatio,
            minTopHeight: minTopHeight,
            minBottomHeight: minBottomHeight,
            view: nsView
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        func configure(
            topRatio: Binding<Double>,
            minTopHeight: CGFloat,
            minBottomHeight: CGFloat,
            view: VerticalResizeDividerNSView
        ) {
            view.onResize = { delta, totalHeight in
                guard totalHeight > 0 else { return }
                let currentTop = CGFloat(topRatio.wrappedValue) * totalHeight
                let newTop = currentTop + delta
                let clamped = min(max(newTop, minTopHeight), totalHeight - minBottomHeight)
                topRatio.wrappedValue = Double(clamped / totalHeight)
            }
        }
    }
}

final class VerticalResizeDividerNSView: NSView {
    var onResize: ((CGFloat, CGFloat) -> Void)?
    private var lastMouseY: CGFloat?
    private var trackingArea: NSTrackingArea?

    override var isOpaque: Bool { false }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeUpDown.set()
    }

    override func mouseDown(with event: NSEvent) {
        lastMouseY = convert(event.locationInWindow, from: nil).y
    }

    override func mouseDragged(with event: NSEvent) {
        let y = convert(event.locationInWindow, from: nil).y
        guard let last = lastMouseY else { return }
        let delta = y - last
        lastMouseY = y
        if let superview {
            onResize?(delta, superview.bounds.height)
        }
    }

    override func mouseUp(with event: NSEvent) {
        lastMouseY = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        let lineY = floor((bounds.height - 1) / 2)
        dirtyRect.intersection(NSRect(x: 0, y: lineY, width: bounds.width, height: 1)).fill()
    }
}
