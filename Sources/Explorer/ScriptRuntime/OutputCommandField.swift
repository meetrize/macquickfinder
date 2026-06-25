import AppKit
import SwiftUI

/// 输出面板底部命令输入框。
final class OutputCommandTextField: NSTextField {
    var onSubmit: (() -> Void)?
    var onTextChange: ((String) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var onHistoryNavigate: ((OutputCommandHistoryDirection) -> String?)?
    var onTabComplete: ((String, Int) -> OutputCommandCompletionResult?)?
    var onCompletionSessionReset: (() -> Void)?

    private var suppressTextSync = false
    private var suppressFocusEndNotification = false
    private var suppressCompletionReset = false
    private var keyMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        removeKeyMonitor()
    }

    private func configure() {
        isEditable = true
        isSelectable = true
        isBordered = false
        drawsBackground = true
        backgroundColor = OutputPanelStyle.commandFieldBackground
        textColor = OutputPanelStyle.commandFieldText
        font = OutputPanelStyle.commandFieldFont
        focusRingType = .none
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingTail
        cell?.wraps = false
        cell?.isScrollable = true
        cell?.truncatesLastVisibleLine = true
        delegate = self
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installKeyMonitorIfNeeded()
        } else {
            removeKeyMonitor()
        }
    }

    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused {
            notifyFocusChanged(true)
        }
        return focused
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            notifyFocusChanged(false)
        }
        return resigned
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handlesReturn(event) {
            submitCommand()
            return
        }
        if handleHistoryArrow(event) {
            return
        }
        if handleTabCompletion(event) {
            return
        }
        super.keyDown(with: event)
    }

    func applyCompletionResult(_ result: OutputCommandCompletionResult) {
        suppressTextSync = true
        stringValue = result.line
        suppressTextSync = false
        suppressCompletionReset = true
        onTextChange?(result.line)
        refocusFieldEditor(cursor: result.cursor)
        DispatchQueue.main.async { [weak self] in
            self?.suppressCompletionReset = false
        }
    }

    func syncText(_ text: String) {
        guard stringValue != text else { return }
        suppressTextSync = true
        stringValue = text
        suppressTextSync = false
    }

    @discardableResult
    func syncTextPreservingFocus(_ text: String) -> Bool {
        guard stringValue != text else { return false }
        let hadFocus = isEditing
        syncText(text)
        return hadFocus
    }

    func refocusFieldEditor(cursor: Int? = nil, selectingAll: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, self.isEnabled else { return }
            guard window.makeFirstResponder(self) else { return }
            guard let editor = self.currentEditor() as? NSTextView else { return }
            if selectingAll {
                editor.selectAll(nil)
            } else if let cursor {
                let clamped = min(max(cursor, 0), (editor.string as NSString).length)
                editor.setSelectedRange(NSRange(location: clamped, length: 0))
            } else {
                editor.moveToEndOfLine(nil)
            }
        }
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isEditing else { return event }
            return self.handleCommandShortcut(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private var isEditing: Bool {
        guard let window else { return false }
        let responder = window.firstResponder
        if responder === self { return true }
        guard let textView = responder as? NSTextView, textView.isFieldEditor else { return false }
        return (textView.delegate as AnyObject?) === self
    }

    private func handleCommandShortcut(_ event: NSEvent) -> Bool {
        guard isEnabled, isEditable else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.control) else { return false }
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }

        let selector: Selector?
        switch key {
        case "a": selector = #selector(NSText.selectAll(_:))
        case "c": selector = #selector(NSText.copy(_:))
        case "v": selector = #selector(NSText.paste(_:))
        case "x": selector = #selector(NSText.cut(_:))
        default: selector = nil
        }

        guard let selector else { return false }
        if let editor = currentEditor(), editor.tryToPerform(selector, with: self) {
            if selector == #selector(NSText.paste(_:)) || selector == #selector(NSText.cut(_:)) {
                onTextChange?(stringValue)
            }
            return true
        }
        if tryToPerform(selector, with: self) {
            if selector == #selector(NSText.paste(_:)) || selector == #selector(NSText.cut(_:)) {
                onTextChange?(stringValue)
            }
            return true
        }
        return false
    }

    private func handlesReturn(_ event: NSEvent) -> Bool {
        guard isEnabled, isEditable else { return false }
        switch event.keyCode {
        case 36, 76: // Return, keypad Enter
            return true
        default:
            return false
        }
    }

    private func submitCommand() {
        suppressFocusEndNotification = true
        onCompletionSessionReset?()
        onTextChange?(stringValue)
        onSubmit?()
        refocusFieldEditor()
        DispatchQueue.main.async { [weak self] in
            self?.suppressFocusEndNotification = false
        }
    }

    private func notifyFocusChanged(_ focused: Bool) {
        onFocusChange?(focused)
        OutputPanelTextEditingCenter.shared.setActive(focused)
    }
}

extension OutputCommandTextField: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        notifyFocusChanged(true)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard !suppressFocusEndNotification else { return }
        notifyFocusChanged(false)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard !suppressTextSync else { return }
        if !suppressCompletionReset {
            onCompletionSessionReset?()
        }
        onTextChange?(stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            submitCommand()
            return true
        }
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            return applyTabCompletion()
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            return applyHistoryNavigation(.up)
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            return applyHistoryNavigation(.down)
        }
        return false
    }

    private func handleTabCompletion(_ event: NSEvent) -> Bool {
        guard event.keyCode == 48 else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.contains(.command), !flags.contains(.control) else { return false }
        return applyTabCompletion()
    }

    @discardableResult
    private func applyTabCompletion() -> Bool {
        guard let onTabComplete else { return false }
        let cursor = currentEditor()?.selectedRange.location ?? (stringValue as NSString).length
        guard let result = onTabComplete(stringValue, cursor) else { return true }
        applyCompletionResult(result)
        return true
    }

    private func handleHistoryArrow(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 126:
            return applyHistoryNavigation(.up)
        case 125:
            return applyHistoryNavigation(.down)
        default:
            return false
        }
    }

    @discardableResult
    private func applyHistoryNavigation(_ direction: OutputCommandHistoryDirection) -> Bool {
        guard let onHistoryNavigate, let value = onHistoryNavigate(direction) else { return false }
        suppressTextSync = true
        stringValue = value
        suppressTextSync = false
        onTextChange?(value)
        refocusFieldEditor()
        return true
    }
}

/// 输出面板底部命令输入框（NSTextField），支持 Cmd+A/C/V/X 与回车提交。
struct OutputCommandField: NSViewRepresentable {
    @Binding var text: String
    var isEnabled: Bool
    var refocusToken: UInt = 0
    var onFocusChange: (Bool) -> Void
    var onSubmit: () -> Void
    var onHistoryNavigate: (OutputCommandHistoryDirection) -> String?
    var onTabComplete: (String, Int) -> OutputCommandCompletionResult?
    var onCompletionSessionReset: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> OutputCommandTextField {
        let field = OutputCommandTextField()
        wire(field, context: context)
        field.syncText(text)
        return field
    }

    func updateNSView(_ nsView: OutputCommandTextField, context: Context) {
        wire(nsView, context: context)
        nsView.isEnabled = isEnabled
        let shouldRefocus = context.coordinator.syncIfNeeded(field: nsView, text: text)
        if shouldRefocus || context.coordinator.lastRefocusToken != refocusToken {
            context.coordinator.lastRefocusToken = refocusToken
            nsView.refocusFieldEditor()
        }
    }

    private func wire(_ field: OutputCommandTextField, context: Context) {
        field.onSubmit = onSubmit
        field.onFocusChange = onFocusChange
        field.onHistoryNavigate = onHistoryNavigate
        field.onTabComplete = onTabComplete
        field.onCompletionSessionReset = onCompletionSessionReset
        field.onTextChange = { context.coordinator.updateText($0) }
    }

    final class Coordinator {
        @Binding var text: String
        var lastRefocusToken: UInt = 0

        init(text: Binding<String>) {
            _text = text
        }

        func updateText(_ value: String) {
            text = value
        }

        func syncIfNeeded(field: OutputCommandTextField, text: String) -> Bool {
            field.syncTextPreservingFocus(text)
        }
    }
}
