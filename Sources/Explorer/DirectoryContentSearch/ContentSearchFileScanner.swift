import Foundation

enum ContentSearchFileScanner {
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

        var results: [ContentSearchMatch] = []
        let lines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var options: NSString.CompareOptions = []
        if !filter.caseSensitive {
            options.insert(.caseInsensitive)
        }

        for (index, lineSubsequence) in lines.enumerated() {
            let line = String(lineSubsequence)
            let nsLine = line as NSString
            var searchRange = NSRange(location: 0, length: nsLine.length)

            while searchRange.location < nsLine.length {
                let found = nsLine.range(of: query, options: options, range: searchRange)
                if found.location == NSNotFound { break }

                results.append(
                    ContentSearchMatch(
                        fileURL: url,
                        relativePath: relativePath,
                        lineNumber: index + 1,
                        lineText: line,
                        matchStartUTF16: found.location,
                        matchLengthUTF16: found.length
                    )
                )

                if results.count >= filter.maxMatchCount { return results }

                let nextLocation = found.location + max(found.length, 1)
                searchRange = NSRange(location: nextLocation, length: nsLine.length - nextLocation)
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
}
