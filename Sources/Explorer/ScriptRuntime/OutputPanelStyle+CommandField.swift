import AppKit
import SwiftUI

extension OutputPanelStyle {
    /// 命令框 / 搜索框：深色底 + 白色文字，无描边。
    static let commandFieldBackground = NSColor(red: 0.165, green: 0.165, blue: 0.18, alpha: 1)
    static let commandFieldText = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
    static let commandFieldFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    static var commandFieldBackgroundColor: Color { Color(nsColor: commandFieldBackground) }
    static var commandFieldTextColor: Color { Color(nsColor: commandFieldText) }
}
