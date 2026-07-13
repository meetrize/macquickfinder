import SwiftUI

enum ExplorerKeyboardShortcuts {
    static let toggleLeftPanel = KeyboardShortcut("b", modifiers: .command)
    static let toggleRightPanel = KeyboardShortcut("b", modifiers: [.command, .shift])

    static let toggleSnippets = KeyboardShortcut("s", modifiers: [.command, .shift])
    static let toggleGit = KeyboardShortcut("g", modifiers: [.command, .shift])
    static let toggleOutputPanel = KeyboardShortcut("j", modifiers: .command)
    static let detachPreview = KeyboardShortcut("p", modifiers: [.command, .option])
    static let togglePreviewBrowserStrip = KeyboardShortcut("b", modifiers: [.command, .option])
    static let connectServer = KeyboardShortcut("k", modifiers: .command)
    static let showAllTabs = KeyboardShortcut("\\", modifiers: [.command, .shift])
    static let newWindow = KeyboardShortcut("n", modifiers: .command)
    static let commandPalette = KeyboardShortcut("p", modifiers: [.command, .shift])
}

