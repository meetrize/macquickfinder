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

    func testMatchesAppPackageByBasenameWhenUnicodeFormDiffers() {
        let nfcName = "汽水音乐.app"
        let item = FileItem(
            id: "/Volumes/SSD4T/app/\(nfcName)",
            url: URL(fileURLWithPath: "/Volumes/SSD4T/app/\(nfcName)"),
            name: nfcName,
            isDirectory: true,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "文件夹",
            sizeDisplay: "",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let nfdName = nfcName.decomposedStringWithCanonicalMapping
        let matched = ExternalSelectionPathMatcher.matchingItem(
            in: [item],
            selectionPath: "/Volumes/SSD4T/app/\(nfdName)"
        )
        XCTAssertEqual(matched?.id, item.id)
    }
}
