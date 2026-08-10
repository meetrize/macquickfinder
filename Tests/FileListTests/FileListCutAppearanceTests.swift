import XCTest
@testable import FileList

final class FileListCutAppearanceTests: XCTestCase {
    func testAlphaMatchesFinderLikeGhosting() {
        XCTAssertEqual(FileListCutAppearance.alpha(isCut: true), 0.45, accuracy: 0.001)
        XCTAssertEqual(FileListCutAppearance.alpha(isCut: false), 1, accuracy: 0.001)
    }

    func testPathSetIncludesRawAndStandardizedPaths() {
        let url = URL(fileURLWithPath: "/tmp/cut-sample.txt")
        let paths = FileListCutAppearance.pathSet(from: [url])
        XCTAssertTrue(paths.contains(url.path))
        XCTAssertTrue(paths.contains(url.standardizedFileURL.path))
    }

    func testIsCutItemMatchesStandardizedPath() {
        let url = URL(fileURLWithPath: "/tmp/./cut-item.txt")
        let cutIDs = FileListCutAppearance.pathSet(from: [url])
        XCTAssertTrue(FileListCutAppearance.isCutItem(id: url.path, cutItemIDs: cutIDs))
        XCTAssertTrue(
            FileListCutAppearance.isCutItem(
                id: url.standardizedFileURL.path,
                cutItemIDs: cutIDs
            )
        )
        XCTAssertFalse(FileListCutAppearance.isCutItem(id: "/tmp/other.txt", cutItemIDs: cutIDs))
        XCTAssertFalse(FileListCutAppearance.isCutItem(id: url.path, cutItemIDs: []))
    }
}
