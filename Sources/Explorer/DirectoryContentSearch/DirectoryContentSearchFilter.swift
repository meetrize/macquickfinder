import Foundation

struct ContentSearchFilter: Equatable, Codable {
    var includePatterns: [String]
    var excludePatterns: [String]
    var includesSubdirectories: Bool
    var caseSensitive: Bool
    var maxFileSizeBytes: Int
    var maxMatchCount: Int
    var useRegex: Bool

    static let `default` = ContentSearchFilter(
        includePatterns: [],
        excludePatterns: ["node_modules/**", ".git/**", "DerivedData/**", "*.xcuserstate"],
        includesSubdirectories: true,
        caseSensitive: false,
        maxFileSizeBytes: 2 * 1024 * 1024,
        maxMatchCount: 200,
        useRegex: false
    )

    var normalizedIncludePatterns: [String] {
        Self.normalizedPatterns(includePatterns)
    }

    var normalizedExcludePatterns: [String] {
        Self.normalizedPatterns(excludePatterns)
    }

    private static func normalizedPatterns(_ patterns: [String]) -> [String] {
        patterns
            .flatMap { $0.split(whereSeparator: \.isWhitespace) }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
