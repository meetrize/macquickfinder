import AppKit
import SwiftUI

extension OutputPanelStyle {
    /// 命令框：深色底 + 琥珀色文字 + 蓝色聚焦描边（与输出区终端风格一致、对比更强）。
    static let commandFieldBackground = NSColor(red: 0.165, green: 0.165, blue: 0.18, alpha: 1)
    static let commandFieldText = NSColor(red: 0.9, green: 0.75, blue: 0.48, alpha: 1)
    static let commandFieldBorder = NSColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1)
    static let commandFieldFocusedBorder = NSColor(red: 0.05, green: 0.56, blue: 1.0, alpha: 1)

    static var commandFieldBackgroundColor: Color { Color(nsColor: commandFieldBackground) }
    static var commandFieldBorderColor: Color { Color(nsColor: commandFieldBorder) }
    static var commandFieldFocusedBorderColor: Color { Color(nsColor: commandFieldFocusedBorder) }
}
