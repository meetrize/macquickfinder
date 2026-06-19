import SwiftUI

enum ExplorerKeyboardShortcuts {
    static let toggleLeftPanel = KeyboardShortcut("b", modifiers: .command)
    static let toggleRightPanel = KeyboardShortcut("b", modifiers: [.command, .shift])

    static let toggleSnippets = KeyboardShortcut("s", modifiers: [.command, .shift])
    static let toggleOutputPanel = KeyboardShortcut("j", modifiers: .command)
    static let detachPreview = KeyboardShortcut("p", modifiers: [.command, .option])
}

