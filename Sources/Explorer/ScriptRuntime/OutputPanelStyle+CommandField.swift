import AppKit
import SwiftUI

extension OutputPanelStyle {
    static let commandFieldFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    static var commandFieldBackground: NSColor { theme.commandFieldBackground.nsColor }
    static var commandFieldText: NSColor { theme.commandFieldText.nsColor }

    static var commandFieldBackgroundColor: Color { theme.commandFieldBackground.color }
    static var commandFieldTextColor: Color { theme.commandFieldText.color }
}
