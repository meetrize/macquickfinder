import AppKit
import Foundation

enum FileListTextHighlight {
    private static func baseAttributes(font: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
    }
    
    private static func nameColor(isHidden: Bool, isSelected: Bool, isEmphasized: Bool) -> NSColor {
        if isSelected {
            return isEmphasized ? .alternateSelectedControlTextColor : .labelColor
        }
        return isHidden ? .secondaryLabelColor : .labelColor
    }
    
    static func attributedName(
        _ text: String,
        searchText: String,
        isDirectory: Bool,
        isHidden: Bool,
        isSelected: Bool = false,
        isEmphasized: Bool = true
    ) -> NSAttributedString {
        let font = isDirectory
            ? NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let color = nameColor(isHidden: isHidden, isSelected: isSelected, isEmphasized: isEmphasized)
        let attributes = baseAttributes(font: font, color: color)
        
        guard !searchText.isEmpty else {
            return NSAttributedString(string: text, attributes: attributes)
        }
        
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSearch.isEmpty else { return result }
        
        var searchStart = text.startIndex
        while searchStart < text.endIndex {
            guard let range = text.range(
                of: normalizedSearch,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex,
                locale: .current
            ) else { break }
            
            let nsRange = NSRange(range, in: text)
            result.addAttribute(
                .backgroundColor,
                value: NSColor.systemYellow.withAlphaComponent(0.45),
                range: nsRange
            )
            searchStart = range.upperBound
        }
        return result
    }
    
    /// 缩略图格子底部 overlay 用：黑字 + 黄底高亮。
    static func attributedOverlayName(
        _ text: String,
        searchText: String,
        isDirectory: Bool,
        isHidden: Bool
    ) -> NSAttributedString {
        let font = isDirectory
            ? NSFont.boldSystemFont(ofSize: 11)
            : NSFont.systemFont(ofSize: 11)
        let color = isHidden ? NSColor.black.withAlphaComponent(0.45) : NSColor.black
        let attributes = baseAttributes(font: font, color: color)
        
        guard !searchText.isEmpty else {
            return NSAttributedString(string: text, attributes: attributes)
        }
        
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSearch.isEmpty else { return result }
        
        var searchStart = text.startIndex
        while searchStart < text.endIndex {
            guard let range = text.range(
                of: normalizedSearch,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex,
                locale: .current
            ) else { break }
            
            let nsRange = NSRange(range, in: text)
            result.addAttribute(
                .backgroundColor,
                value: NSColor.systemYellow.withAlphaComponent(0.65),
                range: nsRange
            )
            result.addAttribute(.foregroundColor, value: NSColor.black, range: nsRange)
            searchStart = range.upperBound
        }
        return result
    }
}
