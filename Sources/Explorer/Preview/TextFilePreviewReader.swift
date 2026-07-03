import Foundation

enum TextFilePreviewReader {
    static let maxCharacters = 20_000
    static let truncationMarker = "\n\n[Content truncated...]"

    static func readPreview(from url: URL) throws -> String {
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let maxBytes = min(max(fileSize, 0), maxCharacters * 4 + 16)
        var data = handle.readData(ofLength: maxBytes)
        while !data.isEmpty, String(data: data, encoding: .utf8) == nil {
            data.removeLast()
        }

        guard var content = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        if content.count > maxCharacters {
            content = String(content.prefix(maxCharacters)) + truncationMarker
        } else if fileSize > data.count {
            content += truncationMarker
        }

        return content
    }
}
