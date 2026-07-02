import AppKit
import SwiftUI

struct OutputPanelRGB: Equatable {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, alpha: CGFloat = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = alpha
    }

    init(white: CGFloat, alpha: CGFloat = 1) {
        self.r = white
        self.g = white
        self.b = white
        self.a = alpha
    }

    var nsColor: NSColor { NSColor(red: r, green: g, blue: b, alpha: a) }
    var color: Color { Color(nsColor: nsColor) }
}

struct OutputPanelTheme: Equatable {
    let background: OutputPanelRGB
    let stdout: OutputPanelRGB
    let stderr: OutputPanelRGB
    let promptPath: OutputPanelRGB
    let promptCommand: OutputPanelRGB
    let placeholder: OutputPanelRGB
    let findHighlight: OutputPanelRGB
    let findHighlightForeground: OutputPanelRGB
    let completionSuccess: OutputPanelRGB
    let completionFailure: OutputPanelRGB
    let completionCancelled: OutputPanelRGB
    let commandBackground: OutputPanelRGB
    let commandText: OutputPanelRGB
    let commandBorder: OutputPanelRGB
    let commandFocusBorder: OutputPanelRGB
    let commandFieldBackground: OutputPanelRGB
    let commandFieldText: OutputPanelRGB
    let commandFieldInactiveBorder: OutputPanelRGB
    let historyRunButtonFill: OutputPanelRGB
    let historyRunButtonIcon: OutputPanelRGB
    let historyRunButtonBorder: OutputPanelRGB
    let scrollerKnob: OutputPanelRGB
    let scrollerTrack: OutputPanelRGB
}

enum OutputPanelColorScheme: String, CaseIterable, Identifiable, Codable {
    case dark
    case light
    case gray

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return L10n.Settings.Snippets.outputColorDark
        case .light: return L10n.Settings.Snippets.outputColorLight
        case .gray: return L10n.Settings.Snippets.outputColorGray
        }
    }

    var theme: OutputPanelTheme {
        switch self {
        case .dark: return .darkTerminal
        case .light: return .lightPaper
        case .gray: return .neutralGray
        }
    }
}

private extension OutputPanelTheme {
    /// 深色终端：琥珀命令条 + 冷灰输出区（默认）。
    static let darkTerminal = OutputPanelTheme(
        background: OutputPanelRGB(0.118, 0.118, 0.118),
        stdout: OutputPanelRGB(0.86, 0.86, 0.86),
        stderr: OutputPanelRGB(1.0, 0.55, 0.55),
        promptPath: OutputPanelRGB(0.36, 0.75, 0.85),
        promptCommand: OutputPanelRGB(0.95, 0.95, 0.95),
        placeholder: OutputPanelRGB(white: 0.55),
        findHighlight: OutputPanelRGB(1.0, 1.0, 0.0, alpha: 0.85),
        findHighlightForeground: OutputPanelRGB(0, 0, 0),
        completionSuccess: OutputPanelRGB(0.45, 0.82, 0.52),
        completionFailure: OutputPanelRGB(1.0, 0.55, 0.55),
        completionCancelled: OutputPanelRGB(white: 0.62),
        commandBackground: OutputPanelRGB(0.16, 0.14, 0.09),
        commandText: OutputPanelRGB(1.0, 0.88, 0.42),
        commandBorder: OutputPanelRGB(0.90, 0.68, 0.22),
        commandFocusBorder: OutputPanelRGB(1.0, 0.82, 0.32),
        commandFieldBackground: OutputPanelRGB(0.165, 0.165, 0.18),
        commandFieldText: OutputPanelRGB(0.95, 0.95, 0.95),
        commandFieldInactiveBorder: OutputPanelRGB(1, 1, 1, alpha: 0.08),
        historyRunButtonFill: OutputPanelRGB(0.95, 0.72, 0.18),
        historyRunButtonIcon: OutputPanelRGB(0.14, 0.11, 0.05),
        historyRunButtonBorder: OutputPanelRGB(1.0, 0.85, 0.35),
        scrollerKnob: OutputPanelRGB(0.82, 0.74, 0.48, alpha: 0.95),
        scrollerTrack: OutputPanelRGB(white: 0.45, alpha: 0.35)
    )

    /// 浅色纸面：高对比正文 + 暖色命令条。
    static let lightPaper = OutputPanelTheme(
        background: OutputPanelRGB(0.965, 0.965, 0.975),
        stdout: OutputPanelRGB(0.12, 0.12, 0.14),
        stderr: OutputPanelRGB(0.78, 0.16, 0.16),
        promptPath: OutputPanelRGB(0.05, 0.45, 0.72),
        promptCommand: OutputPanelRGB(0.15, 0.15, 0.17),
        placeholder: OutputPanelRGB(0.55, 0.55, 0.58),
        findHighlight: OutputPanelRGB(1.0, 0.92, 0.23, alpha: 0.95),
        findHighlightForeground: OutputPanelRGB(0, 0, 0),
        completionSuccess: OutputPanelRGB(0.16, 0.55, 0.28),
        completionFailure: OutputPanelRGB(0.78, 0.16, 0.16),
        completionCancelled: OutputPanelRGB(0.45, 0.45, 0.48),
        commandBackground: OutputPanelRGB(0.98, 0.95, 0.88),
        commandText: OutputPanelRGB(0.45, 0.32, 0.05),
        commandBorder: OutputPanelRGB(0.78, 0.62, 0.22),
        commandFocusBorder: OutputPanelRGB(0.85, 0.65, 0.15),
        commandFieldBackground: OutputPanelRGB(1, 1, 1),
        commandFieldText: OutputPanelRGB(0.12, 0.12, 0.14),
        commandFieldInactiveBorder: OutputPanelRGB(0.82, 0.82, 0.84),
        historyRunButtonFill: OutputPanelRGB(0.92, 0.72, 0.18),
        historyRunButtonIcon: OutputPanelRGB(0.14, 0.11, 0.05),
        historyRunButtonBorder: OutputPanelRGB(0.78, 0.58, 0.12),
        scrollerKnob: OutputPanelRGB(0.65, 0.65, 0.68, alpha: 0.9),
        scrollerTrack: OutputPanelRGB(0.75, 0.75, 0.78, alpha: 0.35)
    )

    /// 中性灰：低饱和控制台风格。
    static let neutralGray = OutputPanelTheme(
        background: OutputPanelRGB(0.22, 0.22, 0.24),
        stdout: OutputPanelRGB(0.82, 0.82, 0.84),
        stderr: OutputPanelRGB(1.0, 0.62, 0.62),
        promptPath: OutputPanelRGB(0.56, 0.78, 0.90),
        promptCommand: OutputPanelRGB(0.92, 0.92, 0.94),
        placeholder: OutputPanelRGB(0.50, 0.50, 0.52),
        findHighlight: OutputPanelRGB(1.0, 0.92, 0.23, alpha: 0.85),
        findHighlightForeground: OutputPanelRGB(0, 0, 0),
        completionSuccess: OutputPanelRGB(0.52, 0.82, 0.58),
        completionFailure: OutputPanelRGB(1.0, 0.62, 0.62),
        completionCancelled: OutputPanelRGB(0.62, 0.62, 0.65),
        commandBackground: OutputPanelRGB(0.28, 0.28, 0.30),
        commandText: OutputPanelRGB(0.88, 0.88, 0.90),
        commandBorder: OutputPanelRGB(0.48, 0.48, 0.50),
        commandFocusBorder: OutputPanelRGB(0.62, 0.62, 0.66),
        commandFieldBackground: OutputPanelRGB(0.30, 0.30, 0.32),
        commandFieldText: OutputPanelRGB(0.92, 0.92, 0.94),
        commandFieldInactiveBorder: OutputPanelRGB(1, 1, 1, alpha: 0.10),
        historyRunButtonFill: OutputPanelRGB(0.55, 0.55, 0.58),
        historyRunButtonIcon: OutputPanelRGB(0.95, 0.95, 0.97),
        historyRunButtonBorder: OutputPanelRGB(0.68, 0.68, 0.70),
        scrollerKnob: OutputPanelRGB(0.60, 0.60, 0.62, alpha: 0.95),
        scrollerTrack: OutputPanelRGB(0.40, 0.40, 0.42, alpha: 0.35)
    )
}
