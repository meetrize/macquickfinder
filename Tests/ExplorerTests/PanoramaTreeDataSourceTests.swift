import XCTest

@testable import Explorer

@MainActor
final class PanoramaTreeDataSourceTests: XCTestCase {
    func testResetSeedsRootListingAndDirectoryNodes() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let photos = root.appendingPathComponent("Photos", isDirectory: true)
        let docURL = root.appendingPathComponent("readme.txt")
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: docURL)

        let rootItems = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let dataSource = PanoramaTreeDataSource()

        dataSource.reset(rootPath: root.path, rootItems: rootItems)

        XCTAssertEqual(dataSource.rootDirectoryPath, root.path)
        XCTAssertEqual(dataSource.loadedItems(for: root.path)?.map(\.name).sorted(), ["Photos", "readme.txt"])
        XCTAssertNotNil(dataSource.node(for: photos.path))
        XCTAssertEqual(dataSource.node(for: photos.path)?.depth, 0)
    }

    func testLoadListingPopulatesChildDirectory() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let photos = root.appendingPathComponent("Photos", isDirectory: true)
        let nested = photos.appendingPathComponent("nested.txt")
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: nested)

        let rootItems = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let dataSource = PanoramaTreeDataSource()
        dataSource.reset(rootPath: root.path, rootItems: rootItems)

        dataSource.loadListing(for: photos.path)
        try await waitUntilLoaded(dataSource, path: photos.path)

        XCTAssertEqual(dataSource.loadedItems(for: photos.path)?.map(\.name), ["nested.txt"])
        XCTAssertEqual(dataSource.node(for: photos.path)?.depth, 0)
    }

    func testResetDiscardsStaleLoad() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let photos = root.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)

        let rootItems = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let dataSource = PanoramaTreeDataSource()
        dataSource.reset(rootPath: root.path, rootItems: rootItems)

        dataSource.loadListing(for: photos.path)
        dataSource.reset(rootPath: root.path, rootItems: rootItems)

        try await Task.sleep(nanoseconds: 200_000_000)

        if case .loaded = dataSource.listing(for: photos.path) {
            XCTFail("Stale load should not mark subdirectory as loaded after reset")
        } else {
            XCTAssertTrue(true)
        }
    }

    func testLRUEvictsOldestLoadedListing() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let first = root.appendingPathComponent("First", isDirectory: true)
        let second = root.appendingPathComponent("Second", isDirectory: true)
        let third = root.appendingPathComponent("Third", isDirectory: true)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: third, withIntermediateDirectories: true)

        let rootItems = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let dataSource = PanoramaTreeDataSource(maxCachedDirectoryListings: 2)
        dataSource.reset(rootPath: root.path, rootItems: rootItems)

        dataSource.loadListing(for: first.path)
        try await waitUntilLoaded(dataSource, path: first.path)

        dataSource.loadListing(for: second.path)
        try await waitUntilLoaded(dataSource, path: second.path)

        dataSource.loadListing(for: third.path)
        try await waitUntilLoaded(dataSource, path: third.path)

        XCTAssertTrue(dataSource.rootListing.isLoaded)
        XCTAssertTrue(dataSource.listing(for: third.path).isLoaded)
        XCTAssertFalse(dataSource.listing(for: first.path).isLoaded)
        XCTAssertTrue(dataSource.loadedPathsForTesting.contains(root.path))
        XCTAssertFalse(dataSource.loadedPathsForTesting.contains(first.path))
    }

    func testEvictListingRemovesDescendantNodes() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let photos = root.appendingPathComponent("Photos", isDirectory: true)
        let vacation = photos.appendingPathComponent("Vacation", isDirectory: true)
        try FileManager.default.createDirectory(at: vacation, withIntermediateDirectories: true)

        let rootItems = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let dataSource = PanoramaTreeDataSource()
        dataSource.reset(rootPath: root.path, rootItems: rootItems)

        dataSource.loadListing(for: photos.path)
        try await waitUntilLoaded(dataSource, path: photos.path)
        XCTAssertNotNil(dataSource.node(for: vacation.path))

        dataSource.evictListing(for: photos.path)

        XCTAssertEqual(dataSource.listing(for: photos.path), .unloaded)
        XCTAssertNil(dataSource.node(for: vacation.path))
    }

    // MARK: - Helpers

    private func waitUntilLoaded(
        _ dataSource: PanoramaTreeDataSource,
        path: String,
        timeout: TimeInterval = 2
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            switch dataSource.listing(for: path) {
            case .loaded, .failed:
                return
            case .unloaded, .loading:
                try await Task.sleep(nanoseconds: 20_000_000)
            }
        }
        XCTFail("Timed out waiting for listing at \(path)")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("panorama-tree-ds-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
