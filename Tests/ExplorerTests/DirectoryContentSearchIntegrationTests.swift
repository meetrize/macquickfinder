import XCTest
@testable import Explorer

final class DirectoryContentSearchIntegrationTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("content-search-integration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    func testGlobAndEngineEndToEnd() async throws {
        let included = tempDirectory.appendingPathComponent("Included.swift")
        let excluded = tempDirectory.appendingPathComponent("node_modules/lib.js")
        try FileManager.default.createDirectory(
            at: tempDirectory.appendingPathComponent("node_modules"),
            withIntermediateDirectories: true
        )
        try "// TODO included".write(to: included, atomically: true, encoding: .utf8)
        try "// TODO excluded".write(to: excluded, atomically: true, encoding: .utf8)

        var filter = ContentSearchFilter.default
        filter.includePatterns = ["*.swift"]

        let engine = DirectoryContentSearchEngine()
        let request = ContentSearchRequest(
            root: tempDirectory,
            query: "TODO",
            filter: filter,
            showHiddenFiles: false,
            generation: 1
        )

        let result = await engine.runSearch(request: request, isCancelled: { false })
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first?.fileURL.lastPathComponent, "Included.swift")
    }
}
