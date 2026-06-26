import XCTest
@testable import Explorer

final class DirectoryListingLoaderTests: XCTestCase {
    func testEnumerationOptionsRespectShowHiddenFiles() {
        let hidden = DirectoryListingLoader.enumerationOptions(showHiddenFiles: false)
        XCTAssertTrue(hidden.contains(.skipsHiddenFiles))
        XCTAssertTrue(hidden.contains(.skipsPackageDescendants))

        let visible = DirectoryListingLoader.enumerationOptions(showHiddenFiles: true)
        XCTAssertFalse(visible.contains(.skipsHiddenFiles))
        XCTAssertTrue(visible.contains(.skipsPackageDescendants))
    }

    func testContentsOfDirectoryMapsToFileItems() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let visible = directory.appendingPathComponent("visible.txt")
        let hidden = directory.appendingPathComponent(".hidden.txt")
        try Data("ok".utf8).write(to: visible)
        try Data("ok".utf8).write(to: hidden)

        let withoutHidden = try DirectoryListingLoader.loadFileItems(
            at: directory.path,
            showHiddenFiles: false
        )
        XCTAssertEqual(withoutHidden.map(\.name).sorted(), ["visible.txt"])

        let withHidden = try DirectoryListingLoader.loadFileItems(
            at: directory.path,
            showHiddenFiles: true
        )
        XCTAssertEqual(Set(withHidden.map(\.name)), Set(["visible.txt", ".hidden.txt"]))
    }

    func testCacheKeyRoundTripViaPropertyKeys() {
        XCTAssertTrue(DirectoryListingLoader.propertyKeys.contains(.isDirectoryKey))
        XCTAssertTrue(DirectoryListingLoader.propertyKeys.contains(.isHiddenKey))
    }

    func testLightweightPropertyKeysExcludeHeavyMetadata() {
        let lightweight = DirectoryListingLoader.propertyKeys(lightweight: true)
        XCTAssertFalse(lightweight.contains(.tagNamesKey))
        XCTAssertFalse(lightweight.contains(.creationDateKey))
        XCTAssertTrue(lightweight.contains(.fileSizeKey))
    }

    func testLightweightFileItemSkipsFinderComment() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: fileURL)

        let keys = DirectoryListingLoader.propertyKeys(lightweight: true)
        let values = try fileURL.resourceValues(forKeys: keys)
        let item = try XCTUnwrap(
            TrashLoader.fileItem(
                from: fileURL,
                propertyKeys: keys,
                prefetchedValues: values,
                skipExtendedMetadata: true
            )
        )

        XCTAssertEqual(item.finderComment, "")
        XCTAssertTrue(item.tags.isEmpty)
    }

    func testDirectoryListingOptionsForPathUsesNetworkVolumeFilter() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertFalse(DirectoryListingOptions.forPath(home).lightweightMetadata)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("directory-listing-loader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
