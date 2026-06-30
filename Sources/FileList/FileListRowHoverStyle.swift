import AppKit

enum FileListRowHoverStyle {
    static func fillColor(for appearance: NSAppearance) -> NSColor {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor.labelColor.withAlphaComponent(isDark ? 0.08 : 0.05)
    }
}
