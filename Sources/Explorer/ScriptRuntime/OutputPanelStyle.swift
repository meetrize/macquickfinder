import AppKit
import SwiftUI

enum OutputPanelStyle {
    static let backgroundColor = Color(red: 0.118, green: 0.118, blue: 0.118)
    static let stdoutColor = Color(red: 0.86, green: 0.86, blue: 0.86)
    static let stderrColor = Color(red: 1.0, green: 0.55, blue: 0.55)

    static var stdoutNSColor: NSColor {
        NSColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1)
    }

    static var stderrNSColor: NSColor {
        NSColor(red: 1.0, green: 0.55, blue: 0.55, alpha: 1)
    }

    static var promptPathNSColor: NSColor {
        NSColor(red: 0.36, green: 0.75, blue: 0.85, alpha: 1)
    }

    static var promptCommandNSColor: NSColor {
        NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
    }

    static var backgroundNSColor: NSColor {
        NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1)
    }
    static let promptPathColor = Color(red: 0.36, green: 0.75, blue: 0.85)
    static let promptCommandColor = Color(red: 0.95, green: 0.95, blue: 0.95)
    static let placeholderColor = Color(white: 0.55)
    static let findHighlightColor = Color(red: 1.0, green: 1.0, blue: 0.0).opacity(0.85)

    static var findHighlightNSColor: NSColor {
        NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.85)
    }
    static let completionSuccessColor = Color(red: 0.45, green: 0.82, blue: 0.52)
    static let completionFailureColor = Color(red: 1.0, green: 0.55, blue: 0.55)
    static let completionCancelledColor = Color(white: 0.62)

    // 命令框：琥珀终端风（暖色输入条，与输出区冷灰/青色提示符对比）
    static let commandBackgroundColor = Color(red: 0.16, green: 0.14, blue: 0.09)
    static let commandTextColor = Color(red: 1.0, green: 0.88, blue: 0.42)
    static let commandBorderColor = Color(red: 0.90, green: 0.68, blue: 0.22)
    static let commandFocusBorderColor = Color(red: 1.0, green: 0.82, blue: 0.32)

    static var commandBackgroundNSColor: NSColor {
        NSColor(red: 0.16, green: 0.14, blue: 0.09, alpha: 1)
    }

    static var commandTextNSColor: NSColor {
        NSColor(red: 1.0, green: 0.88, blue: 0.42, alpha: 1)
    }

    /// 历史列表「直接执行」按钮：琥珀实心底 + 深色图标，在深色行背景上对比更强。
    static let historyRunButtonFill = Color(red: 0.95, green: 0.72, blue: 0.18)
    static let historyRunButtonIcon = Color(red: 0.14, green: 0.11, blue: 0.05)
    static let historyRunButtonBorder = Color(red: 1.0, green: 0.85, blue: 0.35)
}
