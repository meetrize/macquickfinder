import Foundation

enum DirectorySearchMode: String, Codable, CaseIterable, Identifiable {
    case filename
    case content

    var id: String { rawValue }
}

struct ContentSearchMatch: Identifiable, Equatable, Hashable {
    let id: UUID
    let fileURL: URL
    let relativePath: String
    let lineNumber: Int
    let lineText: String
    let matchStartUTF16: Int
    let matchLengthUTF16: Int

    init(
        id: UUID = UUID(),
        fileURL: URL,
        relativePath: String,
        lineNumber: Int,
        lineText: String,
        matchStartUTF16: Int,
        matchLengthUTF16: Int
    ) {
        self.id = id
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.lineNumber = lineNumber
        self.lineText = lineText
        self.matchStartUTF16 = matchStartUTF16
        self.matchLengthUTF16 = matchLengthUTF16
    }
}

struct ContentSearchFileGroup: Identifiable, Equatable {
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

struct ContentSearchProgress: Equatable {
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

struct ContentSearchScanResult: Equatable {
    var matches: [ContentSearchMatch]
    var progress: ContentSearchProgress
}

enum ContentSearchFileEligibility {
    static func isSearchableExtension(_ ext: String) -> Bool {
        BuiltinPreviewExtensions.text.contains(ext.lowercased())
    }
}
