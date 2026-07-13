import XCTest
@testable import Explorer

@MainActor
final class DirectoryContentSearchSessionTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("content-search-session-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    func testCancelClearsResults() async {
        let session = DirectoryContentSearchSession()
        session.query = "TODO"
        session.cancel()
        XCTAssertTrue(session.groups.isEmpty)
        XCTAssertTrue(session.flattenedMatches.isEmpty)
        XCTAssertNil(session.selectedMatchID)
        XCTAssertEqual(session.progress, .idle)
    }

    func testSearchPopulatesResults() async throws {
        let file = tempDirectory.appendingPathComponent("A.swift")
        try "// TODO one\n// TODO two".write(to: file, atomically: true, encoding: .utf8)

        let session = DirectoryContentSearchSession()
        session.updateSearchContext(root: tempDirectory, showHiddenFiles: false)
        session.query = "TODO"

        try await Task.sleep(nanoseconds: 800_000_000)

        XCTAssertEqual(session.flattenedMatches.count, 2)
        XCTAssertEqual(session.groups.count, 1)
        XCTAssertNotNil(session.selectedMatchID)
        XCTAssertTrue(session.progress.isComplete)
    }

    func testSelectNextMatchCycles() async throws {
        let file = tempDirectory.appendingPathComponent("A.swift")
        try "// TODO one\n// TODO two".write(to: file, atomically: true, encoding: .utf8)

        let session = DirectoryContentSearchSession()
        session.updateSearchContext(root: tempDirectory, showHiddenFiles: false)
        session.query = "TODO"
        try await Task.sleep(nanoseconds: 800_000_000)

        let first = session.selectedMatchID
        session.selectNextMatch(forward: true)
        XCTAssertNotEqual(session.selectedMatchID, first)

        session.selectNextMatch(forward: true)
        XCTAssertEqual(session.selectedMatchID, first)
    }

    func testToggleGroupExpansion() async throws {
        let file = tempDirectory.appendingPathComponent("A.swift")
        try "// TODO".write(to: file, atomically: true, encoding: .utf8)

        let session = DirectoryContentSearchSession()
        session.updateSearchContext(root: tempDirectory, showHiddenFiles: false)
        session.query = "TODO"
        try await Task.sleep(nanoseconds: 800_000_000)

        let fileID = session.groups[0].id
        XCTAssertTrue(session.groups[0].isExpanded)

        session.toggleGroupExpansion(fileID: fileID)
        XCTAssertFalse(session.groups[0].isExpanded)
    }
}
