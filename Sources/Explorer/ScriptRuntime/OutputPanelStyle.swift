import AppKit
import SwiftUI

enum OutputPanelStyle {
    static var currentScheme: OutputPanelColorScheme {
        if let raw = UserDefaults.standard.string(forKey: AppPreferences.Snippets.outputColorScheme),
           let scheme = OutputPanelColorScheme(rawValue: raw) {
            return scheme
        }
        return .dark
    }

    static var theme: OutputPanelTheme { currentScheme.theme }

    static var backgroundColor: Color { theme.background.color }
    static var stdoutColor: Color { theme.stdout.color }
    static var stderrColor: Color { theme.stderr.color }

    static var stdoutNSColor: NSColor { theme.stdout.nsColor }
    static var stderrNSColor: NSColor { theme.stderr.nsColor }
    static var promptPathNSColor: NSColor { theme.promptPath.nsColor }
    static var promptCommandNSColor: NSColor { theme.promptCommand.nsColor }
    static var backgroundNSColor: NSColor { theme.background.nsColor }

    static var promptPathColor: Color { theme.promptPath.color }
    static var promptCommandColor: Color { theme.promptCommand.color }
    static var placeholderColor: Color { theme.placeholder.color }
    static var findHighlightColor: Color { theme.findHighlight.color }

    static var findHighlightNSColor: NSColor { theme.findHighlight.nsColor }
    static var findHighlightForegroundNSColor: NSColor { theme.findHighlightForeground.nsColor }

    static var completionSuccessColor: Color { theme.completionSuccess.color }
    static var completionFailureColor: Color { theme.completionFailure.color }
    static var completionCancelledColor: Color { theme.completionCancelled.color }

    static var commandBackgroundColor: Color { theme.commandBackground.color }
    static var commandTextColor: Color { theme.commandText.color }
    static var commandBorderColor: Color { theme.commandBorder.color }
    static var commandFocusBorderColor: Color { theme.commandFocusBorder.color }

    static var commandBackgroundNSColor: NSColor { theme.commandBackground.nsColor }
    static var commandTextNSColor: NSColor { theme.commandText.nsColor }

    static var historyRunButtonFill: Color { theme.historyRunButtonFill.color }
    static var historyRunButtonIcon: Color { theme.historyRunButtonIcon.color }
    static var historyRunButtonBorder: Color { theme.historyRunButtonBorder.color }

    static var scrollerKnobNSColor: NSColor { theme.scrollerKnob.nsColor }
    static var scrollerTrackNSColor: NSColor { theme.scrollerTrack.nsColor }

    static var commandFieldInactiveBorderColor: Color { theme.commandFieldInactiveBorder.color }

    static func applyCommandFieldAppearance(to field: NSTextField) {
        field.backgroundColor = theme.commandFieldBackground.nsColor
        field.textColor = theme.commandFieldText.nsColor
    }

    static func applyCommandFieldAppearance(to textView: NSTextView) {
        textView.textColor = theme.commandFieldText.nsColor
        textView.insertionPointColor = theme.commandFieldText.nsColor
    }

    static func applyFindFieldAppearance(to field: NSTextField, placeholder: String) {
        field.textColor = theme.commandFieldText.nsColor
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: theme.placeholder.nsColor,
                .font: commandFieldFont,
            ]
        )
    }
}
