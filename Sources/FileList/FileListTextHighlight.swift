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
    
    static func attributedName(
        _ text: String,
        searchText: String,
        isDirectory: Bool,
        isHidden: Bool
    ) -> NSAttributedString {
        let font = isDirectory
            ? NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let color: NSColor = isHidden ? .secondaryLabelColor : .labelColor
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
}
