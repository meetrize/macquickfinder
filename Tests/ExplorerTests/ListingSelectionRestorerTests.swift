import XCTest
@testable import Explorer
import FileList

final class ListingSelectionRestorerTests: XCTestCase {
    func testRestoresIDsPresentInLoadedItems() {
        let item = makeFileItem(id: "/tmp/proj/a.swift", name: "a.swift")
        let restored = ListingSelectionRestorer.restoredIDs(
            preserved: [item.id, "/tmp/proj/missing.swift"],
            loadedItems: [item],
            fileExists: { _ in false }
        )
        XCTAssertEqual(restored, [item.id])
    }

    func testRestoresOutOfListingPathsThatStillExistOnDisk() {
        let nested = "/tmp/proj/src/Nested.swift"
        let restored = ListingSelectionRestorer.restoredIDs(
            preserved: [nested],
            loadedItems: [],
            fileExists: { $0 == nested }
        )
        XCTAssertEqual(restored, [nested])
    }

    func testDropsMissingOutOfListingPaths() {
        let restored = ListingSelectionRestorer.restoredIDs(
            preserved: ["/tmp/proj/gone.swift"],
            loadedItems: [],
            fileExists: { _ in false }
        )
        XCTAssertTrue(restored.isEmpty)
    }

    func testIgnoresParentDirectorySentinel() {
        let restored = ListingSelectionRestorer.restoredIDs(
            preserved: [FileItem.parentDirectoryID],
            loadedItems: [],
            fileExists: { _ in true }
        )
        XCTAssertTrue(restored.isEmpty)
    }

    private func makeFileItem(id: String, name: String) -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: id),
            name: name,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 1,
            isHidden: false,
            fileType: "swift",
            sizeDisplay: "1 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }
}
