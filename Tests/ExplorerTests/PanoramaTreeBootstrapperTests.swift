import FileList
import XCTest

@testable import Explorer

@MainActor
final class PanoramaTreeBootstrapperTests: XCTestCase {
    func testVisibleDirectoryQueuedAheadOfDeepLowPriorityDirectory() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        var lowPriorityPaths: [String] = []
        for index in 0..<6 {
            let path = root.appendingPathComponent("Deep-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            lowPriorityPaths.append(path.path)
        }

        let visible = root.appendingPathComponent("Visible", isDirectory: true)
        let visibleNested = visible.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: visibleNested, withIntermediateDirectories: true)

        let rootItems = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let dataSource = PanoramaTreeDataSource()
        dataSource.reset(rootPath: root.path, rootItems: rootItems)

        let bootstrapper = PanoramaTreeBootstrapper()
        bootstrapper.schedule(
            sessionGeneration: dataSource.generation,
            dataSource: dataSource,
            collapseState: PanoramaTreeCollapseState(),
            depthPolicy: .automatic,
            visibleDirectoryPaths: [visible.path]
        )

        let pending = bootstrapper.pendingEntriesForTesting
        guard let visibleEntry = pending.first(where: { $0.path == visible.path }) else {
            return XCTFail("Expected visible directory to be queued")
        }
        XCTAssertEqual(visibleEntry.priority, .visible)

        for path in lowPriorityPaths {
            guard let entry = pending.first(where: { $0.path == path }) else { continue }
            XCTAssertLessThan(entry.priority.rawValue, PanoramaTreeBootstrapper.Priority.visible.rawValue)
        }
    }

    func testListingUpdateEnqueuesChildDirectories() async throws {
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

        let bootstrapper = PanoramaTreeBootstrapper()
        bootstrapper.listingDidUpdate(
            path: photos.path,
            dataSource: dataSource,
            collapseState: PanoramaTreeCollapseState(),
            depthPolicy: .automatic,
            visibleDirectoryPaths: [root.path]
        )

        XCTAssertTrue(
            bootstrapper.pendingEntriesForTesting.contains(where: { $0.path == vacation.path })
                || dataSource.listing(for: vacation.path).isLoaded
        )
    }

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
            .appendingPathComponent("panorama-bootstrapper-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@MainActor
final class PanoramaTreeControllerTests: XCTestCase {
    func testResetBuildsDisplayRoot() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("readme.txt")
        try Data("hello".utf8).write(to: fileURL)

        let items = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let controller = PanoramaTreeController()
        controller.reset(
            rootPath: root.path,
            rootItems: items,
            showHiddenFiles: false,
            sort: .default
        )

        XCTAssertEqual(controller.displayRoot.rootDirectoryPath, root.path)
        XCTAssertFalse(controller.displayRoot.blocks.isEmpty)
    }

    func testToggleCollapseUpdatesDisplay() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let photos = root.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)

        let items = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let controller = PanoramaTreeController()
        controller.reset(
            rootPath: root.path,
            rootItems: items,
            showHiddenFiles: false,
            sort: .default
        )

        let expandedHasSection = flatBlocks(from: controller.displayRoot).contains { block in
            if case let .expandedFolderSection(row, _) = block { return row.id == photos.path }
            return false
        }
        XCTAssertTrue(expandedHasSection)

        controller.toggleCollapse(photos.path)

        let collapsedHasSection = flatBlocks(from: controller.displayRoot).contains { block in
            if case let .expandedFolderSection(row, _) = block { return row.id == photos.path }
            return false
        }
        XCTAssertFalse(collapsedHasSection)
    }

    func testResetDiscardsInFlightListingUpdates() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let photos = root.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)

        let items = try DirectoryListingLoader.loadFileItems(at: root.path, showHiddenFiles: false)
        let controller = PanoramaTreeController()
        controller.reset(
            rootPath: root.path,
            rootItems: items,
            showHiddenFiles: false,
            sort: .default
        )

        controller.dataSource.loadListing(for: photos.path)
        controller.reset(
            rootPath: root.path,
            rootItems: items,
            showHiddenFiles: false,
            sort: .default
        )

        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNotEqual(controller.dataSource.listing(for: photos.path), .loading)
    }

    private func flatBlocks(from display: PanoramaDisplayRoot) -> [PanoramaDisplayBlock] {
        flatten(display.blocks)
    }

    private func flatten(_ blocks: [PanoramaDisplayBlock]) -> [PanoramaDisplayBlock] {
        var result: [PanoramaDisplayBlock] = []
        for block in blocks {
            result.append(block)
            switch block {
            case let .expandedFolderSection(_, children):
                result.append(contentsOf: flatten(children))
            case let .childBlocks(_, children):
                result.append(contentsOf: flatten(children))
            case .itemGrid:
                break
            }
        }
        return result
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("panorama-controller-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
