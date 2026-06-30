import XCTest
@testable import Explorer

final class ArchiveTreeBuilderTests: XCTestCase {
    func testBuildGroupsNestedPathsIntoTree() {
        let entries = [
            ArchiveEntryPreview(path: "docs/readme.md", isDirectory: false, size: nil),
            ArchiveEntryPreview(path: "docs/guide/page.md", isDirectory: false, size: nil),
            ArchiveEntryPreview(path: "photo.png", isDirectory: false, size: nil),
        ]

        let roots = ArchiveTreeBuilder.build(from: entries)
        XCTAssertEqual(roots.map(\.name), ["docs", "photo.png"])
        XCTAssertTrue(roots[0].isDirectory)
        XCTAssertEqual(roots[0].children.map(\.name), ["guide", "readme.md"])
    }

    func testVisibleRowsRespectsExpandedDirectories() {
        let entries = [
            ArchiveEntryPreview(path: "docs/readme.md", isDirectory: false, size: nil),
            ArchiveEntryPreview(path: "docs/guide/page.md", isDirectory: false, size: nil),
        ]
        let roots = ArchiveTreeBuilder.build(from: entries)

        let collapsed = ArchiveTreeBuilder.visibleRows(roots: roots, expandedDirectoryPaths: [])
        XCTAssertEqual(collapsed.map(\.node.name), ["docs"])

        let expanded = ArchiveTreeBuilder.visibleRows(roots: roots, expandedDirectoryPaths: ["docs"])
        XCTAssertEqual(expanded.map(\.node.name), ["docs", "guide", "readme.md"])
    }
}
