import XCTest
@testable import Explorer

final class NetworkDirectoryListingLoaderTests: XCTestCase {
    func testLoadFileItemsUsesReaddirWithoutExtendedMetadata() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let folder = directory.appendingPathComponent("nested", isDirectory: true)
        let file = directory.appendingPathComponent("readme.txt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("ok".utf8).write(to: file)

        let items = try NetworkDirectoryListingLoader.loadFileItems(
            at: directory.path,
            showHiddenFiles: false
        )

        XCTAssertEqual(Set(items.map(\.name)), Set(["nested", "readme.txt"]))
        XCTAssertEqual(items.first(where: { $0.name == "nested" })?.isDirectory, true)
        XCTAssertEqual(items.first(where: { $0.name == "readme.txt" })?.isDirectory, false)
        XCTAssertTrue(items.allSatisfy(\.finderComment.isEmpty))
        XCTAssertTrue(items.allSatisfy(\.tags.isEmpty))
    }

    func testEnrichWithStatFillsSizeAndDate() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("sample.bin")
        try Data(repeating: 0xAB, count: 1_024).write(to: file)

        let placeholders = try NetworkDirectoryListingLoader.loadFileItems(
            at: directory.path,
            showHiddenFiles: false
        )
        let enriched = NetworkDirectoryListingLoader.enrichWithStat(placeholders)
        let fileItem = try XCTUnwrap(enriched.first(where: { $0.name == "sample.bin" }))

        XCTAssertEqual(fileItem.size, 1_024)
        XCTAssertNotEqual(fileItem.dateDisplay, "--")
        XCTAssertFalse(fileItem.isDirectory)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("network-directory-listing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
