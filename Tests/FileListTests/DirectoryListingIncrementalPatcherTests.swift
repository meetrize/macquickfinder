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
        let expected = DirectoryListingPathNormalization.canonicalPath("/tmp/demo/new.txt")
        XCTAssertEqual(patch.addedPaths, [expected])
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
        let expected = DirectoryListingPathNormalization.canonicalPath("/tmp/demo/old.txt")
        XCTAssertEqual(patch.removedPaths, [expected])
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

    func testTmpAndPrivateTmpPathsMatchForRemoval() {
        // /tmp 常为 /private/tmp 的符号链接；事件与 listing 路径字面值可能不同。
        let directory = "/tmp/demo"
        let result = DirectoryListingIncrementalPatcher.evaluate(
            events: [
                DirectoryFSEvent(
                    path: "/private/tmp/demo/old.txt",
                    flags: UInt32(kFSEventStreamEventFlagItemRemoved)
                ),
            ],
            directoryPath: directory
        )
        guard case .patch(let patch) = result else {
            return XCTFail("Expected patch, got \(result)")
        }
        XCTAssertEqual(
            patch.removedPaths,
            [DirectoryListingPathNormalization.canonicalPath("/private/tmp/demo/old.txt")]
        )
    }

    func testTrailingSlashDoesNotBreakParentMatch() {
        let result = DirectoryListingIncrementalPatcher.evaluate(
            events: [
                DirectoryFSEvent(
                    path: "/tmp/demo/gone.txt",
                    flags: UInt32(kFSEventStreamEventFlagItemRemoved)
                ),
            ],
            directoryPath: "/tmp/demo/"
        )
        guard case .patch(let patch) = result else {
            return XCTFail("Expected patch")
        }
        XCTAssertFalse(patch.removedPaths.isEmpty)
    }
}
