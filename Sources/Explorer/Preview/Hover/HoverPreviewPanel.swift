import AppKit
import SwiftUI

/// 单一共享悬停预览面板：不抢焦点、不接收鼠标；跟随光标。
@MainActor
final class HoverPreviewPanel {
    private let panel: NSPanel
    private var hostingView: NSHostingView<HoverPreviewContentView>?
    private var dismissMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var menuObserver: NSObjectProtocol?
    private var currentSize = NSSize(
        width: HoverPreviewMetrics.panelDefaultWidth,
        height: HoverPreviewMetrics.panelDefaultHeight
    )

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
    }

    func present(fileName: String, payload: HoverPreviewPayload, nearMouseIn window: NSWindow?) {
        let size = panelSize(for: payload)
        currentSize = size

        let root = HoverPreviewContentView(fileName: fileName, payload: payload, panelSize: size)
        let host: NSHostingView<HoverPreviewContentView>
        if let existing = hostingView {
            existing.rootView = root
            host = existing
        } else {
            host = NSHostingView(rootView: root)
            hostingView = host
            let effect = NSVisualEffectView()
            effect.material = .popover
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 10
            effect.layer?.masksToBounds = true
            effect.addSubview(host)
            host.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                host.topAnchor.constraint(equalTo: effect.topAnchor),
                host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            ])
            panel.contentView = effect
        }

        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView?.setFrameSize(size)

        let origin = originNearMouse(size: size, window: window)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFront(nil)
        beginDismissSuppressionIfNeeded()
        beginMouseFollowIfNeeded()
    }

    /// 仅根据当前光标重定位（同文件悬停移动时）。
    func repositionNearMouse(window: NSWindow?) {
        guard panel.isVisible else { return }
        let origin = originNearMouse(size: currentSize, window: window)
        panel.setFrameOrigin(origin)
    }

    func dismiss() {
        endMouseFollow()
        endDismissSuppression()
        panel.orderOut(nil)
    }

    var isVisible: Bool { panel.isVisible }

    private func panelSize(for payload: HoverPreviewPayload) -> CGSize {
        let maxW = HoverPreviewMetrics.panelMaxWidth
        let maxH = HoverPreviewMetrics.panelMaxHeight
        let minW = HoverPreviewMetrics.panelMinWidth
        let minH = HoverPreviewMetrics.panelMinHeight
        let defaultW = HoverPreviewMetrics.panelDefaultWidth
        let defaultH = HoverPreviewMetrics.panelDefaultHeight

        switch payload {
        case .image(let image):
            let imageSize = image.size
            guard imageSize.width > 1, imageSize.height > 1 else {
                return CGSize(width: defaultW, height: defaultH)
            }
            let titleBar: CGFloat = 32
            let padding: CGFloat = 20
            let availW = maxW - padding
            let availH = maxH - titleBar - padding
            let scale = min(availW / imageSize.width, availH / imageSize.height, 1)
            let contentW = max(imageSize.width * scale, minW - padding)
            let contentH = max(imageSize.height * scale, minH - titleBar - padding)
            return CGSize(
                width: min(maxW, max(minW, contentW + padding)),
                height: min(maxH, max(minH, contentH + titleBar + padding))
            )
        case .text, .placeholder, .meta:
            return CGSize(width: defaultW, height: defaultH)
        }
    }

    private func originNearMouse(size: NSSize, window: NSWindow?) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = screenFrame(containing: mouse, fallbackWindow: window)
        let inset = HoverPreviewMetrics.screenInset
        var originX = mouse.x + HoverPreviewMetrics.cursorOffsetX
        // AppKit 屏幕坐标 Y 向上；光标上方/下方用偏移。
        var originY = mouse.y + HoverPreviewMetrics.cursorOffsetY - size.height

        if originX + size.width > screen.maxX - inset {
            originX = mouse.x - HoverPreviewMetrics.cursorOffsetX - size.width
        }
        if originX < screen.minX + inset {
            originX = screen.minX + inset
        }
        if originX + size.width > screen.maxX - inset {
            originX = screen.maxX - size.width - inset
        }

        if originY < screen.minY + inset {
            originY = mouse.y + abs(HoverPreviewMetrics.cursorOffsetY)
        }
        if originY + size.height > screen.maxY - inset {
            originY = screen.maxY - size.height - inset
        }
        if originY < screen.minY + inset {
            originY = screen.minY + inset
        }

        return NSPoint(x: originX, y: originY)
    }

    private func screenFrame(containing point: NSPoint, fallbackWindow: NSWindow?) -> NSRect {
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) {
            return screen.visibleFrame
        }
        return fallbackWindow?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? .zero
    }

    private func beginMouseFollowIfNeeded() {
        guard mouseMoveMonitor == nil else { return }
        mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                self.repositionNearMouse(window: event.window)
            }
            return event
        }
    }

    private func endMouseFollow() {
        if let mouseMoveMonitor {
            NSEvent.removeMonitor(mouseMoveMonitor)
            self.mouseMoveMonitor = nil
        }
    }

    private func beginDismissSuppressionIfNeeded() {
        guard dismissMonitor == nil else { return }
        dismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown, .scrollWheel]) { [weak self] event in
            if event.type == .rightMouseDown || event.type == .scrollWheel {
                Task { @MainActor in
                    self?.dismiss()
                }
            }
            return event
        }
        menuObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    private func endDismissSuppression() {
        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
            self.dismissMonitor = nil
        }
        if let menuObserver {
            NotificationCenter.default.removeObserver(menuObserver)
            self.menuObserver = nil
        }
    }
}
