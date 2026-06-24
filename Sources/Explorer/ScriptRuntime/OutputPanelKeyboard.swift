import AppKit

enum OutputPanelKeyboardAction: Equatable {
    case find
    case interrupt
}

enum OutputPanelKeyboard {
    /// 解析输出面板局部快捷键；返回非 nil 时表示应消费该按键。
    static func action(
        for event: NSEvent,
        isFindActive: Bool,
        isInterruptEnabled: Bool
    ) -> OutputPanelKeyboardAction? {
        if isInterruptEnabled, isControlC(event) {
            return .interrupt
        }
        if isFindActive, isCommandF(event) {
            return .find
        }
        return nil
    }

    private static func isControlC(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.control), !flags.contains(.command) else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == "c"
    }

    private static func isCommandF(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == "f"
    }
}
