import AppKit
import SwiftUI

final class ToolbarItemFrameRegistry {
    static let shared = ToolbarItemFrameRegistry()

    private var frames: [String: CGRect] = [:]

    private init() {}

    func update(itemID: String, frameInWindow: CGRect) {
        guard frameInWindow.width > 0, frameInWindow.height > 0 else { return }
        frames[itemID] = frameInWindow
    }

    func remove(itemID: String) {
        frames.removeValue(forKey: itemID)
    }

    func clear() {
        frames.removeAll()
    }

    func itemID(at locationInWindow: NSPoint) -> String? {
        var bestMatch: (id: String, area: CGFloat)?

        for (itemID, frame) in frames where frame.contains(locationInWindow) {
            let area = frame.width * frame.height
            if let bestMatch, area >= bestMatch.area {
                continue
            }
            bestMatch = (itemID, area)
        }

        return bestMatch?.id
    }
}

struct ToolbarItemFrameReporter: NSViewRepresentable {
    let itemID: String

    func makeNSView(context: Context) -> FrameReportingView {
        let view = FrameReportingView()
        view.itemID = itemID
        return view
    }

    func updateNSView(_ nsView: FrameReportingView, context: Context) {
        nsView.itemID = itemID
        nsView.reportFrame()
    }

    static func dismantleNSView(_ nsView: FrameReportingView, coordinator: ()) {
        if !nsView.itemID.isEmpty {
            ToolbarItemFrameRegistry.shared.remove(itemID: nsView.itemID)
        }
    }

    final class FrameReportingView: NSView {
        var itemID: String = ""

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrame()
        }

        override func layout() {
            super.layout()
            reportFrame()
        }

        func reportFrame() {
            guard !itemID.isEmpty, window != nil else { return }
            let frameInWindow = convert(bounds, to: nil)
            ToolbarItemFrameRegistry.shared.update(itemID: itemID, frameInWindow: frameInWindow)
        }
    }
}
