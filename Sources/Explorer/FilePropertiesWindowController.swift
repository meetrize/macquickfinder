import AppKit
import SwiftUI

@MainActor
enum FilePropertiesWindowController {
    static func show(items: [FileItem]) {
        guard !items.isEmpty else { return }

        let viewModel = FilePropertiesWindowViewModel(items: items)
        let rootView = FilePropertiesWindowView(viewModel: viewModel)

        let hostingView = NSHostingView(rootView: rootView)

        let initialSize = NSSize(width: 720, height: 560)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "文件属性"
        window.center()
        window.isReleasedWhenClosed = false

        window.contentView = hostingView
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        if let parentWindow = NSApp.keyWindow {
            // 尽量靠近触发的窗口，提升“右键 -> 打开属性窗”的体感连贯性。
            let originX = parentWindow.frame.midX - window.frame.width / 2
            let originY = parentWindow.frame.midY - window.frame.height / 2
            window.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

