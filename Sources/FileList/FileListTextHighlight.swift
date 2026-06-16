import AppKit
import Foundation

enum FileListTextHighlight {
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
        
        guard !searchText.isEmpty else {
            return NSAttributedString(
                string: text,
                attributes: [.font: font, .foregroundColor: color]
            )
        }
        
        let result = NSMutableAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color]
        )
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
