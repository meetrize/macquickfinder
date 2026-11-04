import Foundation

enum ContentSearchFileScanner {
    /// 每个命中最多保留的片段长度（UTF-16）。
    /// 压缩产物、minified JS 等长行文件里，整行保存会让 200 条命中持有数百 MB。
    static let maxSnippetUTF16Length = 240
    private static let snippetLeadingContextUTF16 = 80

    static func scanFile(
        url: URL,
        root: URL,
        query: String,
        filter: ContentSearchFilter
    ) -> (URL, [ContentSearchMatch]) {
        let relativePath = relativePath(for: url, root: root)
        let matches = scanFileContents(
            url: url,
            relativePath: relativePath,
            query: query,
            filter: filter
        )
        return (url, matches)
    }

    static func scanFileContents(
        url: URL,
        relativePath: String,
        query: String,
        filter: ContentSearchFilter
    ) -> [ContentSearchMatch] {
        guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              fileSize <= filter.maxFileSizeBytes else {
            return []
        }

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              !containsBinaryNUL(in: data) else {
            return []
        }

        guard let content = decodeText(from: data) else { return [] }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var options: String.CompareOptions = []
        if !filter.caseSensitive {
            options.insert(.caseInsensitive)
        }

        var results: [ContentSearchMatch] = []
        let lines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        let minimumLineByteCount = trimmedQuery.utf8.count
        for (index, lineSubsequence) in lines.enumerated() {
            if Task.isCancelled { return results }
            if lineSubsequence.utf8.count < minimumLineByteCount { continue }

            var searchStart = lineSubsequence.startIndex
            // 只在确实命中时才把该行转成 NSString，未命中的行完全不桥接。
            var nsLine: NSString?

            while searchStart < lineSubsequence.endIndex {
                guard let found = lineSubsequence.range(
                    of: trimmedQuery,
                    options: options,
                    range: searchStart..<lineSubsequence.endIndex
                ) else {
                    break
                }

                let line = nsLine ?? {
                    let value = String(lineSubsequence) as NSString
                    nsLine = value
                    return value
                }()

                let matchStartUTF16 = utf16Offset(of: found.lowerBound, in: lineSubsequence)
                let matchLengthUTF16 = lineSubsequence[found].utf16.count
                let snippet = makeSnippet(
                    line: line,
                    matchLocation: matchStartUTF16,
                    matchLength: matchLengthUTF16
                )

                results.append(
                    ContentSearchMatch(
                        fileURL: url,
                        relativePath: relativePath,
                        lineNumber: index + 1,
                        lineText: snippet.text,
                        matchStartUTF16: snippet.matchStartUTF16,
                        matchLengthUTF16: matchLengthUTF16,
                        lineColumnUTF16: matchStartUTF16
                    )
                )

                if results.count >= filter.maxMatchCount { return results }

                guard found.upperBound > found.lowerBound else { break }
                searchStart = found.upperBound
            }
        }

        return results
    }

    static func containsBinaryNUL(in data: Data) -> Bool {
        let sampleCount = min(data.count, 8192)
        guard sampleCount > 0 else { return false }
        return data.prefix(sampleCount).contains(0)
    }

    static func decodeText(from data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let utf16 = String(data: data, encoding: .utf16) { return utf16 }
        return String(data: data, encoding: .isoLatin1)
    }

    static func relativePath(for fileURL: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        if filePath.hasPrefix(rootPath + "/") {
            return String(filePath.dropFirst(rootPath.count + 1))
        }
        if filePath == rootPath {
            return fileURL.lastPathComponent
        }
        return fileURL.lastPathComponent
    }

    private static func utf16Offset(of index: String.Index, in string: Substring) -> Int {
        index.utf16Offset(in: string)
    }

    struct Snippet: Equatable {
        let text: String
        let matchStartUTF16: Int
    }

    /// 截取命中附近的窗口，并用 `…` 标记被裁剪的一侧。
    static func makeSnippet(line: NSString, matchLocation: Int, matchLength: Int) -> Snippet {
        let maxLength = maxSnippetUTF16Length
        guard line.length > maxLength else {
            return Snippet(text: line as String, matchStartUTF16: matchLocation)
        }

        var start = safeStartBoundary(
            max(0, matchLocation - snippetLeadingContextUTF16),
            in: line
        )
        var end = min(line.length, max(start + maxLength, matchLocation + matchLength))

        if end - start > maxLength {
            if matchLength >= maxLength {
                start = matchLocation
                end = min(line.length, matchLocation + matchLength)
            } else {
                start = max(0, end - maxLength)
            }
        }

        start = safeStartBoundary(start, in: line)
        end = safeEndBoundary(end, in: line)
        start = min(start, end)

        let core = line.substring(with: NSRange(location: start, length: end - start))
        let hasLeadingEllipsis = start > 0
        let hasTrailingEllipsis = end < line.length
        let text = (hasLeadingEllipsis ? "…" : "") + core + (hasTrailingEllipsis ? "…" : "")
        let matchStartUTF16 = (matchLocation - start) + (hasLeadingEllipsis ? 1 : 0)
        return Snippet(text: text, matchStartUTF16: matchStartUTF16)
    }

    /// 避免把代理对切成两半。
    private static func safeStartBoundary(_ index: Int, in line: NSString) -> Int {
        guard index > 0, index < line.length else { return index }
        let unit = line.character(at: index)
        if unit >= 0xDC00, unit <= 0xDFFF { return index - 1 }
        return index
    }

    private static func safeEndBoundary(_ index: Int, in line: NSString) -> Int {
        guard index > 0, index < line.length else { return index }
        let previous = line.character(at: index - 1)
        if previous >= 0xD800, previous <= 0xDBFF { return index + 1 }
        return index
    }
}
