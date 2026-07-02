import AppKit

/// 输出面板深色背景下的 overlay 滚动条样式。
enum OutputPanelScrollerStyle {
    static func installVerticalOverlayScroller(on scrollView: NSScrollView) {
        scrollView.scrollerStyle = .overlay
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        let scroller = OutputPanelOverlayScroller()
        scroller.scrollerStyle = .overlay
        scroller.controlSize = .mini
        scrollView.verticalScroller = scroller
    }
}

final class OutputPanelOverlayScroller: NSScroller {
    override func drawKnob() {
        let knobRect = rect(for: .knob)
        guard knobRect.height > 2, knobRect.width > 2 else { return }
        let inset = knobRect.insetBy(dx: 1.5, dy: 2)
        let path = NSBezierPath(roundedRect: inset, xRadius: 3, yRadius: 3)
        OutputPanelStyle.scrollerKnobNSColor.setFill()
        path.fill()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        guard slotRect.height > 0 else { return }
        OutputPanelStyle.scrollerTrackNSColor.setFill()
        slotRect.fill()
    }
}
