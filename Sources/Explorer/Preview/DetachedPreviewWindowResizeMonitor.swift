import AppKit
import SwiftUI

/// 监听独立预览窗尺寸变化：保留工具栏 / 胶片条，仅缩放图片区。
struct DetachedPreviewWindowResizeMonitor: NSViewRepresentable {
    let sessionID: PreviewSessionID

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionID: sessionID)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView)
        }
    }

    @MainActor
    final class Coordinator {
        let sessionID: PreviewSessionID
        private weak var observedWindow: NSWindow?
        private var resizeObserver: NSObjectProtocol?
        private var liveResizeObserver: NSObjectProtocol?

        init(sessionID: PreviewSessionID) {
            self.sessionID = sessionID
        }

        func attach(to view: NSView) {
            guard let window = view.window else { return }
            guard observedWindow !== window else { return }
            removeObservers()
            observedWindow = window

            liveResizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willStartLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleResize()
                }
            }

            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleResize()
                }
            }
        }

        private func handleResize() {
            guard let session = PreviewSessionStore.shared.session(for: sessionID) else { return }
            session.adaptImageToWindowOnResize = true
            session.image.zoomScale = 1.0
        }

        private func removeObservers() {
            if let liveResizeObserver {
                NotificationCenter.default.removeObserver(liveResizeObserver)
                self.liveResizeObserver = nil
            }
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
                self.resizeObserver = nil
            }
            observedWindow = nil
        }
    }
}
