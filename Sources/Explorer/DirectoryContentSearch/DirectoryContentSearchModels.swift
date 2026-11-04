import Foundation

enum DirectorySearchMode: String, Codable, CaseIterable, Identifiable {
    case filename
    case content

    var id: String { rawValue }
}

struct ContentSearchMatch: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let fileURL: URL
    let relativePath: String
    let lineNumber: Int
    /// 命中片段（最多几百个 UTF-16 单元），不再保存整行，避免长行被多条命中重复持有。
    let lineText: String
    /// 命中在 `lineText` 片段内的 UTF-16 偏移，用于结果列表高亮。
    let matchStartUTF16: Int
    let matchLengthUTF16: Int
    /// 命中在原始行内的 UTF-16 列偏移，用于预览精确跳转。
    let lineColumnUTF16: Int

    init(
        id: UUID = UUID(),
        fileURL: URL,
        relativePath: String,
        lineNumber: Int,
        lineText: String,
        matchStartUTF16: Int,
        matchLengthUTF16: Int,
        lineColumnUTF16: Int? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.lineNumber = lineNumber
        self.lineText = lineText
        self.matchStartUTF16 = matchStartUTF16
        self.matchLengthUTF16 = matchLengthUTF16
        self.lineColumnUTF16 = lineColumnUTF16 ?? matchStartUTF16
    }
}

struct ContentSearchFileGroup: Identifiable, Equatable, Sendable {
    let id: String
    let fileURL: URL
    let relativePath: String
    var matches: [ContentSearchMatch]
    var isExpanded: Bool

    init(
        fileURL: URL,
        relativePath: String,
        matches: [ContentSearchMatch],
        isExpanded: Bool = true
    ) {
        self.id = fileURL.path
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.matches = matches
        self.isExpanded = isExpanded
    }
}

struct ContentSearchProgress: Equatable, Sendable {
    var scannedFileCount: Int
    var totalFileCount: Int?
    var matchCount: Int
    var elapsed: TimeInterval
    var isComplete: Bool
    var wasCancelled: Bool
    var wasTruncated: Bool

    static let idle = ContentSearchProgress(
        scannedFileCount: 0,
        totalFileCount: nil,
        matchCount: 0,
        elapsed: 0,
        isComplete: false,
        wasCancelled: false,
        wasTruncated: false
    )
}

struct ContentSearchScanResult: Equatable, Sendable {
    var matches: [ContentSearchMatch]
    var progress: ContentSearchProgress
}

enum ContentSearchFileEligibility {
    static func isSearchableExtension(_ ext: String) -> Bool {
        BuiltinPreviewExtensions.text.contains(ext.lowercased())
    }
}
