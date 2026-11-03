import AppKit
import SwiftUI

/// 贴在侧栏行背后的右键监听：右键 / Control+点击落在该行时先执行选中回调，
/// 然后把事件原样交回，让 SwiftUI 的 `.contextMenu` 照常弹出。
/// 视图本身不参与命中测试，不会影响左键点击与拖放。
struct SidebarRowRightClickSelection: NSViewRepresentable {
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughRightClickAnchorView()
        context.coordinator.anchorView = view
        context.coordinator.onRightClick = onRightClick
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.anchorView = nsView
        context.coordinator.onRightClick = onRightClick
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var anchorView: NSView?
        var onRightClick: (() -> Void)?
        private var monitor: Any?

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handle(_ event: NSEvent) {
            guard let anchorView,
                  let window = anchorView.window,
                  event.window === window else { return }

            if event.type == .leftMouseDown {
                guard event.modifierFlags.contains(.control) else { return }
            }

            let point = anchorView.convert(event.locationInWindow, from: nil)
            guard anchorView.visibleRect.contains(point) else { return }
            onRightClick?()
        }
    }
}

/// 仅作为坐标参照，永不被命中，事件全部穿透给下层 SwiftUI 视图。
private final class PassthroughRightClickAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
