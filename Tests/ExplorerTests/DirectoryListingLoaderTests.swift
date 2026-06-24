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

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("directory-listing-loader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
