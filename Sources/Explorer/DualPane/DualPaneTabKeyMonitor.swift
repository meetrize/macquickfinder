import AppKit
import SwiftUI

/// 双栏模式下用 Tab 切换活动栏（路径栏/重命名编辑中不抢）。
struct DualPaneTabKeyMonitor: NSViewRepresentable {
    var isEnabled: Bool
    var onToggle: () -> Void

    func makeNSView(context: Context) -> DualPaneTabKeyMonitorView {
        let view = DualPaneTabKeyMonitorView()
        view.isEnabled = isEnabled
        view.onToggle = onToggle
        return view
    }

    func updateNSView(_ nsView: DualPaneTabKeyMonitorView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onToggle = onToggle
    }
}

final class DualPaneTabKeyMonitorView: NSView {
    var isEnabled = false
    var onToggle: (() -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installMonitorIfNeeded()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isEnabled else { return event }
            guard event.keyCode == 48 else { return event } // Tab
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
                return event
            }
            self.onToggle?()
            return nil
        }
    }
}
