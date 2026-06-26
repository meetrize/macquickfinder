import AppKit
import Carbon

struct ShortcutBinding: Codable, Equatable, Hashable {
    var keyCode: UInt16
    var modifiers: UInt

    static let defaultGlobalToggle = ShortcutBinding(
        keyCode: 49,
        modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue
    )

    init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
    }

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        let eventFlags = modifierFlags
        if eventFlags.contains(.command) { flags |= UInt32(cmdKey) }
        if eventFlags.contains(.shift) { flags |= UInt32(shiftKey) }
        if eventFlags.contains(.option) { flags |= UInt32(optionKey) }
        if eventFlags.contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    var displayString: String {
        var parts: [String] = []
        let eventFlags = modifierFlags
        if eventFlags.contains(.control) { parts.append("⌃") }
        if eventFlags.contains(.option) { parts.append("⌥") }
        if eventFlags.contains(.shift) { parts.append("⇧") }
        if eventFlags.contains(.command) { parts.append("⌘") }
        parts.append(KeyCodeMap.displayCharacter(for: keyCode))
        return parts.joined()
    }

    func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifierFlags
    }
}

enum KeyCodeMap {
    private static let characterToKeyCode: [Character: UInt16] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34,
        "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15,
        "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
        ",": 43, ".": 47, "/": 44, ";": 41, "'": 39, "[": 33, "]": 30, "\\": 42, "-": 27, "=": 24, "`": 50,
    ]

    private static let keyCodeToDisplay: [UInt16: String] = [
        36: "↩", 76: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
        117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 114: "Help", 115: "Home", 116: "PgUp",
        118: "F4", 119: "End", 120: "F2", 121: "PgDn", 122: "F1",
    ]

    static func displayCharacter(for keyCode: UInt16) -> String {
        if let display = keyCodeToDisplay[keyCode] {
            return display
        }
        if let character = characterToKeyCode.first(where: { $0.value == keyCode })?.key {
            return String(character).uppercased()
        }
        return "?"
    }
}
