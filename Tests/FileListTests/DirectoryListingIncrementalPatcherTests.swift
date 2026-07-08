import XCTest
@testable import FileList

final class DirectoryListingIncrementalPatcherTests: XCTestCase {
    func testCreatedFileProducesAddedPatch() {
        let directory = "/tmp/demo"
        let result = DirectoryListingIncrementalPatcher.evaluate(
            events: [
                DirectoryFSEvent(path: "/tmp/demo/new.txt", flags: UInt32(kFSEventStreamEventFlagItemCreated)),
            ],
            directoryPath: directory
        )
        guard case .patch(let patch) = result else {
            return XCTFail("Expected patch")
        }
        XCTAssertEqual(patch.addedPaths, ["/tmp/demo/new.txt"])
        XCTAssertTrue(patch.removedPaths.isEmpty)
    }

    func testRemovedFileProducesRemovedPatch() {
        let directory = "/tmp/demo"
        let result = DirectoryListingIncrementalPatcher.evaluate(
            events: [
                DirectoryFSEvent(path: "/tmp/demo/old.txt", flags: UInt32(kFSEventStreamEventFlagItemRemoved)),
            ],
            directoryPath: directory
        )
        guard case .patch(let patch) = result else {
            return XCTFail("Expected patch")
        }
        XCTAssertEqual(patch.removedPaths, ["/tmp/demo/old.txt"])
        XCTAssertTrue(patch.addedPaths.isEmpty)
    }

    func testModifiedOnlyDoesNotChangeListing() {
        let directory = "/tmp/demo"
        let result = DirectoryListingIncrementalPatcher.evaluate(
            events: [
                DirectoryFSEvent(path: "/tmp/demo/file.txt", flags: UInt32(kFSEventStreamEventFlagItemModified)),
            ],
            directoryPath: directory
        )
        XCTAssertEqual(result, .noListingChange)
    }

    func testRenameRequiresFullReload() {
        let directory = "/tmp/demo"
        let result = DirectoryListingIncrementalPatcher.evaluate(
            events: [
                DirectoryFSEvent(
                    path: "/tmp/demo/renamed.txt",
                    flags: UInt32(kFSEventStreamEventFlagItemRenamed)
                ),
            ],
            directoryPath: directory
        )
        XCTAssertEqual(result, .requiresFullReload)
    }
}
