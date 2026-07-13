import XCTest
@testable import Explorer

final class DirectoryContentSearchModelsTests: XCTestCase {
    func testDefaultFilterValues() {
        let filter = ContentSearchFilter.default
        XCTAssertTrue(filter.includesSubdirectories)
        XCTAssertFalse(filter.caseSensitive)
        XCTAssertEqual(filter.maxFileSizeBytes, 2 * 1024 * 1024)
        XCTAssertEqual(filter.maxMatchCount, 200)
        XCTAssertTrue(filter.normalizedExcludePatterns.contains("node_modules/**"))
    }

    func testFilterCodableRoundTrip() throws {
        var filter = ContentSearchFilter.default
        filter.includePatterns = ["*.swift", "*.md"]
        filter.caseSensitive = true

        let data = try JSONEncoder().encode(filter)
        let decoded = try JSONDecoder().decode(ContentSearchFilter.self, from: data)
        XCTAssertEqual(decoded, filter)
    }

    func testMakeGroupsPreservesOrderAndExpansion() {
        let root = URL(fileURLWithPath: "/tmp/project")
        let fileA = root.appendingPathComponent("A.swift")
        let fileB = root.appendingPathComponent("B.swift")
        let matches = [
            ContentSearchMatch(
                fileURL: fileB,
                relativePath: "B.swift",
                lineNumber: 1,
                lineText: "TODO",
                matchStartUTF16: 0,
                matchLengthUTF16: 4
            ),
            ContentSearchMatch(
                fileURL: fileA,
                relativePath: "A.swift",
                lineNumber: 2,
                lineText: "TODO",
                matchStartUTF16: 0,
                matchLengthUTF16: 4
            ),
        ]

        let groups = DirectoryContentSearchSession.makeGroups(
            from: matches,
            userExpansionOverrides: [:],
            defaultExpandedCount: 1
        )

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].fileURL.lastPathComponent, "A.swift")
        XCTAssertTrue(groups[0].isExpanded)
        XCTAssertFalse(groups[1].isExpanded)
    }
}
