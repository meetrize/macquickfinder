import XCTest
@testable import Explorer

final class ArchiveMemberPathResolverTests: XCTestCase {
    private let entries: [ArchiveEntryPreview] = [
        ArchiveEntryPreview(path: "docs/readme.md", isDirectory: false, size: 10),
        ArchiveEntryPreview(path: "docs/guide/", isDirectory: true, size: nil),
        ArchiveEntryPreview(path: "docs/guide/page.md", isDirectory: false, size: 20),
        ArchiveEntryPreview(path: "photo.png", isDirectory: false, size: 30),
    ]

    func testCollapsedSelectionExpandsDirectoryPrefix() {
        let paths = ArchiveMemberPathResolver.resolveMemberPaths(
            selectedPaths: ["docs"],
            allEntries: entries,
            expanded: false
        )
        XCTAssertTrue(paths.contains("docs/readme.md"))
        XCTAssertTrue(paths.contains("docs/guide/page.md"))
    }

    func testExpandedSelectionIncludesDirectoryDescendants() {
        let paths = ArchiveMemberPathResolver.resolveMemberPaths(
            selectedPaths: ["docs/guide/"],
            allEntries: entries,
            expanded: true
        )
        XCTAssertEqual(paths, ["docs/guide", "docs/guide/", "docs/guide/page.md"])
    }

    func testSingleFileSelection() {
        let paths = ArchiveMemberPathResolver.resolveMemberPaths(
            selectedPaths: ["photo.png"],
            allEntries: entries,
            expanded: true
        )
        XCTAssertEqual(paths, ["photo.png"])
    }
}
