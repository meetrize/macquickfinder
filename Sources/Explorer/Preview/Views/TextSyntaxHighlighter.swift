import AppKit
import Foundation

enum TextSyntaxHighlighter {
    private enum Language {
        case swift
        case javascript
        case python
        case json
        case shell
        case rust
        case vue
    }

    private struct Palette {
        let plain: NSColor
        let keyword: NSColor
        let string: NSColor
        let comment: NSColor
        let number: NSColor
        let key: NSColor
    }

    private static let cache = NSCache<NSString, NSAttributedString>()
    private static let maxHighlightCharacters = 18_000
    private static let maxHighlightLines = 1_200

    static func makePlainText(text: String, fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    static func highlightedText(
        text: String,
        fileExtension: String,
        fontSize: CGFloat,
        isDark: Bool
    ) -> NSAttributedString {
        guard shouldHighlight(text: text) else {
            return makePlainText(text: text, fontSize: fontSize)
        }
        guard let language = language(for: fileExtension) else {
            return makePlainText(text: text, fontSize: fontSize)
        }
        let key = cacheKey(text: text, fileExtension: fileExtension, fontSize: fontSize, isDark: isDark)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        let palette = palette(isDark: isDark)
        let result = highlight(text: text, language: language, fontSize: fontSize, palette: palette)
        cache.setObject(result, forKey: key as NSString)
        return result
    }

    private static func shouldHighlight(text: String) -> Bool {
        if text.count > maxHighlightCharacters { return false }
        var lineCount = 1
        for scalar in text.unicodeScalars where scalar == "\n" {
            lineCount += 1
            if lineCount > maxHighlightLines { return false }
        }
        return true
    }

    private static func language(for ext: String) -> Language? {
        switch ext.lowercased() {
        case "swift":
            return .swift
        case "js", "jsx", "ts", "tsx":
            return .javascript
        case "py":
            return .python
        case "json":
            return .json
        case "sh", "bash", "zsh":
            return .shell
        case "rs":
            return .rust
        case "vue":
            return .vue
        default:
            return nil
        }
    }

    private static func palette(isDark: Bool) -> Palette {
        if isDark {
            return Palette(
                plain: NSColor(calibratedRed: 0.86, green: 0.88, blue: 0.91, alpha: 1),
                keyword: NSColor(calibratedRed: 0.49, green: 0.68, blue: 0.96, alpha: 1),
                string: NSColor(calibratedRed: 0.60, green: 0.85, blue: 0.64, alpha: 1),
                comment: NSColor(calibratedRed: 0.52, green: 0.59, blue: 0.65, alpha: 1),
                number: NSColor(calibratedRed: 0.95, green: 0.73, blue: 0.46, alpha: 1),
                key: NSColor(calibratedRed: 0.91, green: 0.60, blue: 0.78, alpha: 1)
            )
        }
        return Palette(
            plain: NSColor.labelColor,
            keyword: NSColor(calibratedRed: 0.07, green: 0.32, blue: 0.79, alpha: 1),
            string: NSColor(calibratedRed: 0.13, green: 0.53, blue: 0.17, alpha: 1),
            comment: NSColor(calibratedRed: 0.42, green: 0.47, blue: 0.52, alpha: 1),
            number: NSColor(calibratedRed: 0.75, green: 0.41, blue: 0.09, alpha: 1),
            key: NSColor(calibratedRed: 0.62, green: 0.24, blue: 0.54, alpha: 1)
        )
    }

    private static func highlight(text: String, language: Language, fontSize: CGFloat, palette: Palette) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: palette.plain
            ]
        )
        let fullRange = NSRange(location: 0, length: attributed.length)
        let protectedRanges = NSMutableArray()

        func apply(_ regex: NSRegularExpression, color: NSColor, protectedToken: Bool = false) {
            let matches = regex.matches(in: text, options: [], range: fullRange)
            for match in matches {
                if match.range.length == 0 { continue }
                if intersectsProtected(match.range, protectedRanges) { continue }
                attributed.addAttribute(.foregroundColor, value: color, range: match.range)
                if protectedToken {
                    protectedRanges.add(NSValue(range: match.range))
                }
            }
        }

        switch language {
        case .swift:
            apply(swiftCommentRegex, color: palette.comment, protectedToken: true)
            apply(swiftStringRegex, color: palette.string, protectedToken: true)
            apply(swiftKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .javascript:
            apply(jsCommentRegex, color: palette.comment, protectedToken: true)
            apply(jsStringRegex, color: palette.string, protectedToken: true)
            apply(jsKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .python:
            apply(pythonCommentRegex, color: palette.comment, protectedToken: true)
            apply(pythonStringRegex, color: palette.string, protectedToken: true)
            apply(pythonKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .json:
            apply(jsonStringRegex, color: palette.string, protectedToken: true)
            apply(jsonKeyRegex, color: palette.key)
            apply(jsonKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .shell:
            apply(shellCommentRegex, color: palette.comment, protectedToken: true)
            apply(shellStringRegex, color: palette.string, protectedToken: true)
            apply(shellKeywordRegex, color: palette.keyword)
            apply(shellVariableRegex, color: palette.number)
            apply(numberRegex, color: palette.number)
        case .rust:
            apply(rustCommentRegex, color: palette.comment, protectedToken: true)
            apply(rustStringRegex, color: palette.string, protectedToken: true)
            apply(rustKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .vue:
            apply(vueCommentRegex, color: palette.comment, protectedToken: true)
            apply(vueTagRegex, color: palette.key)
            apply(vueAttrRegex, color: palette.keyword)
            apply(vueStringRegex, color: palette.string, protectedToken: true)
            apply(jsKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        }

        return attributed
    }

    private static func intersectsProtected(_ range: NSRange, _ protectedRanges: NSMutableArray) -> Bool {
        for value in protectedRanges {
            guard let nsValue = value as? NSValue else { continue }
            if NSIntersectionRange(range, nsValue.rangeValue).length > 0 {
                return true
            }
        }
        return false
    }

    private static func cacheKey(text: String, fileExtension: String, fontSize: CGFloat, isDark: Bool) -> String {
        let digest = fnv1a64(text)
        return "\(fileExtension.lowercased())|\(Int(fontSize.rounded()))|\(isDark ? 1 : 0)|\(text.count)|\(digest)"
    }

    private static func fnv1a64(_ input: String) -> UInt64 {
        let prime: UInt64 = 1_099_511_628_211
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return hash
    }

    private static let numberRegex = try! NSRegularExpression(pattern: #"(?<![\w.])\d+(?:\.\d+)?(?![\w.])"#)

    private static let swiftCommentRegex = try! NSRegularExpression(pattern: #"//.*|/\*[\s\S]*?\*/"#)
    private static let swiftStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*""#)
    private static let swiftKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:func|let|var|if|else|switch|case|for|while|guard|return|class|struct|enum|protocol|extension|import|private|fileprivate|internal|public|open|static|mutating|async|await|throw|throws|do|catch|in|where|nil|true|false)\b"#
    )

    private static let jsCommentRegex = try! NSRegularExpression(pattern: #"//.*|/\*[\s\S]*?\*/"#)
    private static let jsStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#)
    private static let jsKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:function|const|let|var|if|else|switch|case|for|while|return|class|extends|import|export|default|async|await|try|catch|throw|new|null|undefined|true|false)\b"#
    )

    private static let pythonCommentRegex = try! NSRegularExpression(pattern: #"(?m)#.*$"#)
    private static let pythonStringRegex = try! NSRegularExpression(pattern: #"'''[\s\S]*?'''|"""[\s\S]*?"""|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*""#)
    private static let pythonKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:def|class|if|elif|else|for|while|try|except|finally|return|import|from|as|with|lambda|yield|async|await|pass|break|continue|None|True|False)\b"#
    )

    private static let jsonStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*""#)
    private static let jsonKeyRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"(?=\s*:)"#)
    private static let jsonKeywordRegex = try! NSRegularExpression(pattern: #"\b(?:true|false|null)\b"#)

    private static let shellCommentRegex = try! NSRegularExpression(pattern: #"(?m)#.*$"#)
    private static let shellStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#)
    private static let shellKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:if|then|else|fi|for|in|do|done|case|esac|while|function|return|export|local)\b"#
    )
    private static let shellVariableRegex = try! NSRegularExpression(pattern: #"\$(?:[A-Za-z_]\w*|\{[^}]+\})"#)

    private static let rustCommentRegex = try! NSRegularExpression(pattern: #"//.*|/\*[\s\S]*?\*/"#)
    private static let rustStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#)
    private static let rustKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:fn|let|mut|if|else|match|for|while|loop|return|struct|enum|impl|trait|use|mod|pub|crate|super|self|where|as|const|static|async|await|move|unsafe|dyn|ref|type|true|false|None|Some|Result|Option)\b"#
    )

    private static let vueCommentRegex = try! NSRegularExpression(pattern: #"<!--[\s\S]*?-->|//.*|/\*[\s\S]*?\*/"#)
    private static let vueTagRegex = try! NSRegularExpression(pattern: #"</?[A-Za-z][\w:-]*"#)
    private static let vueAttrRegex = try! NSRegularExpression(pattern: #"\s(?:v-[\w:-]+|:[\w:-]+|@[\w:-]+|[\w:-]+)(?=\=)"#)
    private static let vueStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#)
}
