import XCTest
@testable import Explorer

final class ExternalSelectionPathMatcherTests: XCTestCase {
    func testMatchesStandardizedItemID() {
        let item = FileItem(
            id: "/tmp/example/file.png",
            url: URL(fileURLWithPath: "/tmp/example/file.png"),
            name: "file.png",
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "png",
            sizeDisplay: "",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let matched = ExternalSelectionPathMatcher.matchingItem(
            in: [item],
            selectionPath: "/tmp/example//file.png"
        )
        XCTAssertEqual(matched?.id, item.id)
    }

    func testMatchesWhenItemIDUsesSymlinkResolvedForm() {
        let item = FileItem(
            id: "/private/tmp/example/file.png",
            url: URL(fileURLWithPath: "/private/tmp/example/file.png"),
            name: "file.png",
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "png",
            sizeDisplay: "",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let matched = ExternalSelectionPathMatcher.matchingItem(
            in: [item],
            selectionPath: "/tmp/example/file.png"
        )
        XCTAssertEqual(matched?.id, item.id)
    }
}
