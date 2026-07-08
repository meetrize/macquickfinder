import AppKit
import Foundation

/// SVG 预览辅助：解析逻辑尺寸并按显示预算栅格化。
enum SVGPreviewSupport {
    static func isSVGURL(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "svg"
    }

    static func isSVGData(_ data: Data) -> Bool {
        guard let prefix = String(data: data.prefix(512), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }
        return prefix.hasPrefix("<svg") || prefix.contains("<svg")
    }

    static func logicalSize(from markup: String) -> CGSize? {
        guard let openRange = markup.range(of: "<svg", options: .caseInsensitive) else { return nil }
        let tail = markup[openRange.lowerBound...]
        guard let closeRange = tail.range(of: ">") else { return nil }
        let tag = String(tail[..<closeRange.upperBound])

        let width = parseLengthAttribute(named: "width", in: tag)
        let height = parseLengthAttribute(named: "height", in: tag)
        if let width, let height, width > 0, height > 0 {
            return CGSize(width: width, height: height)
        }

        if let viewBox = parseViewBox(in: tag), viewBox.width > 0, viewBox.height > 0 {
            return CGSize(width: viewBox.width, height: viewBox.height)
        }

        if let width, width > 0 { return CGSize(width: width, height: width) }
        if let height, height > 0 { return CGSize(width: height, height: height) }
        return nil
    }

    static func decode(from url: URL, maxPixelSize: Int?) -> NSImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data: data, maxPixelSize: maxPixelSize)
    }

    static func decode(data: Data, maxPixelSize: Int?) -> NSImage? {
        let markup = markupString(from: data)
        let logical = markup.flatMap(logicalSize(from:)) ?? CGSize(width: 300, height: 150)
        let renderSize = rasterSize(logical: logical, maxPixelSize: maxPixelSize)

        if let markup, let image = MarkdownPreviewMermaidRenderer.makeImage(fromSVG: markup, size: renderSize) {
            image.size = logical
            return image
        }

        if let image = NSImage(data: data), image.isValid {
            image.size = logical
            return image
        }

        return nil
    }

    static func markupStringForDimensions(from data: Data) -> String? {
        markupString(from: data)
    }

    private static func markupString(from data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let latin1 = String(data: data, encoding: .isoLatin1) { return latin1 }
        return String(decoding: data, as: UTF8.self)
    }

    private static func rasterSize(logical: CGSize, maxPixelSize: Int?) -> NSSize {
        let longest = max(logical.width, logical.height, 1)
        let budget = CGFloat(max(maxPixelSize ?? ImagePreviewLoader.defaultDisplayPixelBudget, 1))
        let scale = budget / longest
        return NSSize(width: logical.width * scale, height: logical.height * scale)
    }

    private static func parseLengthAttribute(named name: String, in tag: String) -> CGFloat? {
        let pattern = #"\#(name)\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: tag) else {
            return nil
        }
        return parseNumericLength(String(tag[valueRange]))
    }

    private static func parseViewBox(in tag: String) -> CGRect? {
        let pattern = #"viewBox\s*=\s*["']\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              match.numberOfRanges > 4,
              let xRange = Range(match.range(at: 1), in: tag),
              let yRange = Range(match.range(at: 2), in: tag),
              let widthRange = Range(match.range(at: 3), in: tag),
              let heightRange = Range(match.range(at: 4), in: tag),
              let x = Double(tag[xRange]),
              let y = Double(tag[yRange]),
              let width = Double(tag[widthRange]),
              let height = Double(tag[heightRange]) else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func parseNumericLength(_ raw: String) -> CGFloat? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasSuffix("%") { return nil }

        var number = ""
        for character in trimmed {
            if character.isNumber || character == "." || character == "-" {
                number.append(character)
            } else {
                break
            }
        }
        guard let value = Double(number), value > 0 else { return nil }
        return CGFloat(value)
    }
}
