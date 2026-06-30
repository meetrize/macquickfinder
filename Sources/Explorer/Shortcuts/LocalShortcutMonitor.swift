import AppKit
import SwiftUI

/// 监听可配置本地快捷键（仅当前应用、窗口为 key 时生效）。
struct LocalShortcutMonitor: NSViewRepresentable {
    let binding: ShortcutBinding
    var isEnabled: Bool = true
    let action: () -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onShortcut = action
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.binding = binding
        nsView.isEnabled = isEnabled
        nsView.onShortcut = action
        nsView.syncMonitor()
    }

    final class MonitorView: NSView {
        var binding: ShortcutBinding = .defaultNewTab
        var isEnabled = true
        var onShortcut: (() -> Void)?
        private var monitor: Any?

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            syncMonitor()
        }

        func syncMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            guard isEnabled, window != nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isEnabled else { return event }
                guard self.window?.isKeyWindow == true else { return event }
                guard self.binding.matches(event) else { return event }
                self.onShortcut?()
                return nil
            }
        }
    }
}
