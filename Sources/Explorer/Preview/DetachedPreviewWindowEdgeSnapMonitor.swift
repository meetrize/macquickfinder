import AppKit
import SwiftUI

/// 监听窗口展示 / 布局，在独立预览窗打开后自动贴齐可见区域。
struct DetachedPreviewWindowEdgeSnapMonitor: NSViewRepresentable {
    let sessionID: PreviewSessionID
    let fitImageToScreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionID: sessionID, fitImageToScreen: fitImageToScreen)
    }

    func makeNSView(context: Context) -> FrameClampHostingView {
        let view = FrameClampHostingView()
        view.coordinator = context.coordinator
        DispatchQueue.main.async {
            context.coordinator.attach(to: view)
        }
        return view
    }

    func updateNSView(_ nsView: FrameClampHostingView, context: Context) {
        nsView.coordinator = context.coordinator
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView)
        }
    }

    @MainActor
    final class Coordinator {
        let sessionID: PreviewSessionID
        let fitImageToScreen: Bool
        private weak var observedWindow: NSWindow?
        private weak var clampView: FrameClampHostingView?
        private var becomeKeyObserver: NSObjectProtocol?
        private var resizeObserver: NSObjectProtocol?
        private var screenParametersObserver: NSObjectProtocol?
        private var initialSnapDeadline = Date.distantPast

        init(sessionID: PreviewSessionID, fitImageToScreen: Bool) {
            self.sessionID = sessionID
            self.fitImageToScreen = fitImageToScreen
        }

        func attach(to view: FrameClampHostingView) {
            guard fitImageToScreen else { return }
            clampView = view
            guard let window = view.window else { return }
            guard observedWindow !== window else { return }
            removeObservers()
            observedWindow = window
            initialSnapDeadline = Date().addingTimeInterval(1.0)
            view.clampDeadline = initialSnapDeadline

            becomeKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                Task { @MainActor in
                    guard let self, let window else { return }
                    self.snap(window: window)
                }
            }

            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                Task { @MainActor in
                    guard let self, let window else { return }
                    guard Date() < self.initialSnapDeadline else { return }
                    self.snap(window: window)
                }
            }

            screenParametersObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self, weak window] _ in
                Task { @MainActor in
                    guard let self, let window else { return }
                    self.snap(window: window)
                }
            }

            snap(window: window)
            let session = PreviewSessionStore.shared.session(for: sessionID)
            let pixelSize = session.flatMap { session -> CGSize? in
                if session.image.sourcePixelSize.width > 0, session.image.sourcePixelSize.height > 0 {
                    return session.image.sourcePixelSize
                }
                return ImageFileDimensionsReader.pixelSize(for: session.file.url)
            }
            DetachedPreviewWindowSizer.scheduleEdgeSnaps(
                for: window,
                browserStripExpanded: session?.isBrowserStripExpanded ?? true,
                canBrowse: session?.browseContext?.canBrowse ?? false,
                imagePixelSize: pixelSize
            )
        }

        private func snap(window: NSWindow) {
            let session = PreviewSessionStore.shared.session(for: sessionID)
            DetachedPreviewWindowSizer.snapToVisibleArea(for: session, window: window)
        }

        private func removeObservers() {
            if let becomeKeyObserver {
                NotificationCenter.default.removeObserver(becomeKeyObserver)
                self.becomeKeyObserver = nil
            }
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
                self.resizeObserver = nil
            }
            if let screenParametersObserver {
                NotificationCenter.default.removeObserver(screenParametersObserver)
                self.screenParametersObserver = nil
            }
            clampView?.clampDeadline = .distantPast
            observedWindow = nil
            initialSnapDeadline = Date.distantPast
        }
    }
}

@MainActor
final class FrameClampHostingView: NSView {
    weak var coordinator: DetachedPreviewWindowEdgeSnapMonitor.Coordinator?
    var clampDeadline = Date.distantPast

    override func layout() {
        super.layout()
        guard Date() < clampDeadline, let window else { return }
        DetachedPreviewWindowSizer.clampWindowFrameToVisibleArea(window)
    }
}
