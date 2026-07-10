import Foundation

private extension String.Encoding {
    static let gb18030 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
    )
}

/// 缩略图用 Markdown 摘要：首个 ATX 标题 + 正文预览；无标题时首行约 15 字作标题。
struct MarkdownThumbnailSnippet: Equatable {
    let titleText: String
    /// 1…6 为 ATX 标题级别；无标题 fallback 时为 `nil`。
    let headingLevel: Int?
    let bodyPreview: String
    let isFallbackTitle: Bool
}

enum MarkdownThumbnailSnippetExtractor {
    static let maxReadBytes = 8_192
    static let fallbackTitleMaxLength = 15
    static let bodyMaxLines = 3
    static let bodyMaxCharacters = 120

    private static let atxHeadingRegex = try? NSRegularExpression(
        pattern: "^[ \\t]{0,3}(#{1,6})\\s+(.+)$",
        options: []
    )
    private static let frontMatterMarkerRegex = try? NSRegularExpression(
        pattern: #"^[\t ]*(-{3,}|\*{3,}|_{3,})[\t ]*$"#,
        options: []
    )
    private static let bulletPrefixRegex = try? NSRegularExpression(
        pattern: "^[ \\t]*([-*+]|\\d+\\.)\\s+",
        options: []
    )
    private static let fencePrefixRegex = try? NSRegularExpression(
        pattern: "^[ \\t]*```",
        options: []
    )
    private static let inlineLinkRegex = try? NSRegularExpression(
        pattern: #"\[([^\]]+)\]\([^)]*\)"#,
        options: []
    )
    private static let inlineImageRegex = try? NSRegularExpression(
        pattern: #"!\[([^\]]*)\]\([^)]*\)"#,
        options: []
    )

    static func readPreviewText(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maxReadBytes), !data.isEmpty else { return nil }
        return decodePreviewText(from: data)
    }

    /// 将读取到的字节解码为预览文本；优先 UTF-8，并处理截断在多字节字符中间的情况。
    static func decodePreviewText(from data: Data) -> String? {
        let utf8Data = utf8SafePrefix(of: data)
        if let text = String(data: utf8Data, encoding: .utf8), !text.isEmpty {
            return text
        }

        if let text = String(data: data, encoding: .utf16), !text.isEmpty {
            return text
        }
        if let text = String(data: data, encoding: .utf16LittleEndian), !text.isEmpty {
            return text
        }
        if let text = String(data: data, encoding: .utf16BigEndian), !text.isEmpty {
            return text
        }
        if let text = String(data: data, encoding: .gb18030), !text.isEmpty {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1), !text.isEmpty {
            return text
        }
        return nil
    }

    /// 截断到完整 UTF-8 码点边界，避免 8KB 硬切导致解码失败或乱码。
    static func utf8SafePrefix(of data: Data) -> Data {
        var end = data.count
        while end > 0 {
            if String(data: data.prefix(end), encoding: .utf8) != nil {
                return Data(data.prefix(end))
            }
            end -= 1
        }
        return data
    }

    static func extract(from text: String) -> MarkdownThumbnailSnippet? {
        let normalized = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        guard !lines.isEmpty else { return nil }

        let frontMatter = frontMatterLineIndices(in: lines)
        var inFence = false

        if let heading = firstHeading(
            in: lines,
            frontMatter: frontMatter,
            inFence: &inFence
        ) {
            let body = collectBodyPreview(
                in: lines,
                startingAt: heading.lineIndex + 1,
                frontMatter: frontMatter,
                skipHeadingLineIndices: [heading.lineIndex]
            )
            return MarkdownThumbnailSnippet(
                titleText: heading.text,
                headingLevel: heading.level,
                bodyPreview: body,
                isFallbackTitle: false
            )
        }

        inFence = false
        if let fallback = firstMeaningfulLine(
            in: lines,
            frontMatter: frontMatter,
            inFence: &inFence
        ) {
            let title = truncateFallbackTitle(fallback.plainText)
            let body = collectBodyPreview(
                in: lines,
                startingAt: fallback.lineIndex,
                frontMatter: frontMatter,
                skipHeadingLineIndices: [],
                titleFallbackPrefixLength: title.count
            )
            guard !title.isEmpty || !body.isEmpty else { return nil }
            return MarkdownThumbnailSnippet(
                titleText: title.isEmpty ? body : title,
                headingLevel: nil,
                bodyPreview: title.isEmpty ? "" : body,
                isFallbackTitle: true
            )
        }

        return nil
    }

    // MARK: - Private

    private struct HeadingMatch {
        let lineIndex: Int
        let level: Int
        let text: String
    }

    private struct MeaningfulLine {
        let lineIndex: Int
        let plainText: String
    }

    private static func firstHeading(
        in lines: [String],
        frontMatter: Set<Int>,
        inFence: inout Bool
    ) -> HeadingMatch? {
        for (index, line) in lines.enumerated() {
            if updateFenceState(for: line, inFence: &inFence) { continue }
            if frontMatter.contains(index) || inFence { continue }
            guard let match = parseATXHeading(line) else { continue }
            let title = stripInlineMarkdown(match.text)
            guard !title.isEmpty else { continue }
            return HeadingMatch(lineIndex: index, level: match.level, text: title)
        }
        return nil
    }

    private static func firstMeaningfulLine(
        in lines: [String],
        frontMatter: Set<Int>,
        inFence: inout Bool
    ) -> MeaningfulLine? {
        for (index, line) in lines.enumerated() {
            if updateFenceState(for: line, inFence: &inFence) { continue }
            if frontMatter.contains(index) || inFence { continue }
            if isSkippableBodyLine(line) { continue }
            let plain = stripLineDecorations(line)
            guard !plain.isEmpty else { continue }
            return MeaningfulLine(lineIndex: index, plainText: plain)
        }
        return nil
    }

    private static func collectBodyPreview(
        in lines: [String],
        startingAt startIndex: Int,
        frontMatter: Set<Int>,
        skipHeadingLineIndices: Set<Int>,
        titleFallbackPrefixLength: Int = 0
    ) -> String {
        var inFence = false
        var collected: [String] = []
        var totalCharacters = 0

        for index in startIndex..<lines.count {
            let line = lines[index]
            if updateFenceState(for: line, inFence: &inFence) { continue }
            if frontMatter.contains(index) || inFence { continue }
            if skipHeadingLineIndices.contains(index) { continue }

            var plain = stripLineDecorations(line)
            if index == startIndex, titleFallbackPrefixLength > 0 {
                plain = String(plain.dropFirst(min(titleFallbackPrefixLength, plain.count)))
                    .trimmingCharacters(in: .whitespaces)
            }
            if plain.isEmpty || isSkippableBodyLine(line) { continue }

            collected.append(plain)
            totalCharacters += plain.count
            if collected.count >= bodyMaxLines || totalCharacters >= bodyMaxCharacters { break }
        }

        var joined = collected.joined(separator: "\n")
        if joined.count > bodyMaxCharacters {
            joined = String(joined.prefix(bodyMaxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return joined
    }

    private static func parseATXHeading(_ line: String) -> (level: Int, text: String)? {
        guard let atxHeadingRegex else { return nil }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard
            let match = atxHeadingRegex.firstMatch(in: line, options: [], range: range),
            match.numberOfRanges >= 3,
            match.range(at: 2).location != NSNotFound
        else { return nil }

        let level = max(1, min(6, match.range(at: 1).length))
        let text = nsLine.substring(with: match.range(at: 2))
        return (level, text)
    }

    private static func frontMatterLineIndices(in lines: [String]) -> Set<Int> {
        guard lines.first.map(isFrontMatterMarkerLine) == true else { return [] }

        var indices: Set<Int> = [0]
        for index in 1..<lines.count {
            if isFrontMatterMarkerLine(lines[index]) {
                indices.insert(index)
                return indices
            }
            indices.insert(index)
        }
        return [0]
    }

    private static func isFrontMatterMarkerLine(_ line: String) -> Bool {
        guard let frontMatterMarkerRegex else { return false }
        let range = NSRange(location: 0, length: (line as NSString).length)
        return frontMatterMarkerRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    private static func updateFenceState(for line: String, inFence: inout Bool) -> Bool {
        guard isFenceLine(line) else { return false }
        inFence.toggle()
        return true
    }

    private static func isFenceLine(_ line: String) -> Bool {
        guard let fencePrefixRegex else { return false }
        let range = NSRange(location: 0, length: (line as NSString).length)
        return fencePrefixRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    private static func isSkippableBodyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        if parseATXHeading(line) != nil { return true }
        if isFrontMatterMarkerLine(line) { return true }
        if isFenceLine(line) { return true }
        if isListLine(line) { return true }
        if trimmed.hasPrefix(">") { return true }
        return false
    }

    private static func isListLine(_ line: String) -> Bool {
        guard let bulletPrefixRegex else { return false }
        let range = NSRange(location: 0, length: (line as NSString).length)
        return bulletPrefixRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    private static func stripLineDecorations(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        if let bulletPrefixRegex {
            let range = NSRange(location: 0, length: (text as NSString).length)
            text = bulletPrefixRegex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: ""
            )
        }
        if text.hasPrefix(">") {
            text = text.drop(while: { $0 == ">" || $0 == " " }).trimmingCharacters(in: .whitespaces)
        }
        return stripInlineMarkdown(text)
    }

    static func stripInlineMarkdown(_ text: String) -> String {
        var result = text
        if let inlineImageRegex {
            let range = NSRange(location: 0, length: (result as NSString).length)
            result = inlineImageRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1"
            )
        }
        if let inlineLinkRegex {
            let range = NSRange(location: 0, length: (result as NSString).length)
            result = inlineLinkRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1"
            )
        }
        result = result
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func truncateFallbackTitle(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= fallbackTitleMaxLength { return trimmed }

        let index = trimmed.index(trimmed.startIndex, offsetBy: fallbackTitleMaxLength)
        var slice = String(trimmed[..<index])
        if let punctuation = slice.last, "，。！？、；：,.!?;:".contains(punctuation) {
            slice.removeLast()
        }
        return slice.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
