import SwiftUI
import AppKit

extension FocusedValues {
    var previewTextSelectionActive: Bool? {
        get { self[PreviewTextSelectionActiveKey.self] }
        set { self[PreviewTextSelectionActiveKey.self] = newValue }
    }
}

struct PreviewTextSelectionActiveKey: FocusedValueKey {
    typealias Value = Bool
}

enum TextEditingCommands {
    static func send(_ selector: Selector) {
        if let responder = NSApp.keyWindow?.firstResponder,
           responder.tryToPerform(selector, with: nil) {
            return
        }
        NSApp.sendAction(selector, to: nil, from: nil)
    }

    @ViewBuilder
    static func previewSelectionButtons() -> some View {
        Button("全选") {
            send(#selector(NSText.selectAll(_:)))
        }
        .keyboardShortcut("a", modifiers: .command)

        Button("复制") {
            send(#selector(NSText.copy(_:)))
        }
        .keyboardShortcut("c", modifiers: .command)
    }

    @ViewBuilder
    static func pasteboardButtons() -> some View {
        Button("全选") {
            send(#selector(NSText.selectAll(_:)))
        }
        .keyboardShortcut("a", modifiers: .command)

        Button("剪切") {
            send(#selector(NSText.cut(_:)))
        }
        .keyboardShortcut("x", modifiers: .command)

        Button("复制") {
            send(#selector(NSText.copy(_:)))
        }
        .keyboardShortcut("c", modifiers: .command)

        Button("粘贴") {
            send(#selector(NSText.paste(_:)))
        }
        .keyboardShortcut("v", modifiers: .command)
    }
}

/// 当 SwiftUI TextField 获得焦点时，拦截 Cmd+A/C/V/X 并转发给当前 field editor。
struct TextEditingKeyMonitor: NSViewRepresentable {
    let isActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PassThroughKeyMonitorNSView {
        let view = PassThroughKeyMonitorNSView()
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: PassThroughKeyMonitorNSView, context: Context) {
        context.coordinator.isActive = isActive
    }

    final class Coordinator {
        var isActive = false
        private var monitor: Any?

        func install(on view: NSView) {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event)
            }
        }

        private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
            guard isActive else { return event }
            guard event.modifierFlags.contains(.command) else { return event }
            guard let key = event.charactersIgnoringModifiers?.lowercased() else { return event }

            let selector: Selector?
            switch key {
            case "a": selector = #selector(NSText.selectAll(_:))
            case "c": selector = #selector(NSText.copy(_:))
            case "v": selector = #selector(NSText.paste(_:))
            case "x": selector = #selector(NSText.cut(_:))
            default: selector = nil
            }

            guard let selector else { return event }
            TextEditingCommands.send(selector)
            return nil
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// 仅用于挂载键盘监听，不参与鼠标命中测试。
final class PassThroughKeyMonitorNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
