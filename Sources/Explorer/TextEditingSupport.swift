import SwiftUI
import AppKit

struct PreviewTextSelectionActiveKey: FocusedValueKey {
    typealias Value = Bool
}

struct PreviewTextEditActiveKey: FocusedValueKey {
    typealias Value = Bool
}

struct PreviewTextEditSaveHandlerKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var previewTextSelectionActive: Bool? {
        get { self[PreviewTextSelectionActiveKey.self] }
        set { self[PreviewTextSelectionActiveKey.self] = newValue }
    }

    var previewTextEditActive: Bool? {
        get { self[PreviewTextEditActiveKey.self] }
        set { self[PreviewTextEditActiveKey.self] = newValue }
    }

    var previewTextEditSave: (() -> Void)? {
        get { self[PreviewTextEditSaveHandlerKey.self] }
        set { self[PreviewTextEditSaveHandlerKey.self] = newValue }
    }
}

enum TextEditingCommands {
    static func send(_ selector: Selector) {
        if let responder = NSApp.keyWindow?.firstResponder,
           responder.tryToPerform(selector, with: nil) {
            return
        }
        NSApp.sendAction(selector, to: nil, from: nil)
    }

    static func isFieldEditorFirstResponder(in window: NSWindow? = NSApp.keyWindow) -> Bool {
        guard let textView = window?.firstResponder as? NSTextView else { return false }
        return textView.isFieldEditor
    }

    static func editSelector(for event: NSEvent) -> Selector? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.control), !flags.contains(.option) else {
            return nil
        }
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return nil }
        switch key {
        case "a": return #selector(NSText.selectAll(_:))
        case "c": return #selector(NSText.copy(_:))
        case "v": return #selector(NSText.paste(_:))
        case "x": return #selector(NSText.cut(_:))
        case "z":
            if flags.contains(.shift) {
                return NSSelectorFromString("redo:")
            }
            return NSSelectorFromString("undo:")
        default: return nil
        }
    }

    /// 供 `NSTextField` / `NSSecureTextField` 子类在 `performKeyEquivalent` 中调用。
    @discardableResult
    static func performEditKeyEquivalent(with event: NSEvent, on field: NSTextField) -> Bool {
        guard let selector = editSelector(for: event) else { return false }
        if let editor = field.currentEditor(), editor.tryToPerform(selector, with: field) {
            return true
        }
        if field.tryToPerform(selector, with: field) {
            return true
        }
        return NSApp.sendAction(selector, to: nil, from: field)
    }

    static func performEditAction(for event: NSEvent) -> Bool {
        guard let selector = editSelector(for: event) else { return false }
        send(selector)
        return true
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
            guard TextEditingCommands.performEditAction(for: event) else { return event }
            return nil
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// 当 field editor（SwiftUI TextField）为第一响应者时，拦截 Cmd+A/C/V/X 并转发。
/// 适用于独立窗口等无法依赖 FocusState + `TextEditingKeyMonitor` 的场景。
struct FieldEditorTextEditingKeyMonitor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PassThroughKeyMonitorNSView {
        let view = PassThroughKeyMonitorNSView()
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: PassThroughKeyMonitorNSView, context: Context) {}

    final class Coordinator {
        private var monitor: Any?

        func install(on view: NSView) {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event)
            }
        }

        private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
            guard TextEditingCommands.isFieldEditorFirstResponder() else { return event }
            guard TextEditingCommands.performEditAction(for: event) else { return event }
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

// MARK: - AppKit 可编辑文本框（⌘C/V/X/A/Z）

/// `NSAlert` accessory / 模态对话框里的标准 `NSTextField` 往往收不到编辑菜单快捷键。
/// 新建可编辑 AppKit 输入框时用本工厂，勿直接用裸 `NSTextField` / `NSSecureTextField`。
enum KeyEquivalentTextFields {
    static func plain(frame: NSRect) -> NSTextField {
        KeyEquivalentTextField(frame: frame)
    }

    static func secure(frame: NSRect) -> NSSecureTextField {
        KeyEquivalentSecureTextField(frame: frame)
    }
}

final class KeyEquivalentTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if TextEditingCommands.performEditKeyEquivalent(with: event, on: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class KeyEquivalentSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if TextEditingCommands.performEditKeyEquivalent(with: event, on: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
