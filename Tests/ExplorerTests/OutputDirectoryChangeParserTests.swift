import XCTest
@testable import Explorer

final class OutputDirectoryChangeParserTests: XCTestCase {
    private var baseURL: URL!
    private var subURL: URL!

    override func setUpWithError() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-cd-parser-\(UUID().uuidString)", isDirectory: true)
        baseURL = root.appendingPathComponent("Projects", isDirectory: true)
        subURL = baseURL.appendingPathComponent("Sub", isDirectory: true)
        try FileManager.default.createDirectory(at: subURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let baseURL {
            try? FileManager.default.removeItem(at: baseURL.deletingLastPathComponent())
        }
    }

    func testCdRelativePath() {
        let result = OutputDirectoryChangeParser.resolveLeadingDirectoryChange(
            expandedCommand: "cd Sub",
            currentDirectory: baseURL.path,
            previousDirectory: nil
        )
        XCTAssertEqual(result, (subURL.path as NSString).standardizingPath)
    }

    func testCdHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let result = OutputDirectoryChangeParser.resolveLeadingDirectoryChange(
            expandedCommand: "cd",
            currentDirectory: baseURL.path,
            previousDirectory: nil
        )
        XCTAssertEqual(result, (home as NSString).standardizingPath)
    }

    func testCdChainBeforeOtherCommand() {
        let result = OutputDirectoryChangeParser.resolveLeadingDirectoryChange(
            expandedCommand: "cd .. && ls",
            currentDirectory: subURL.path,
            previousDirectory: nil
        )
        XCTAssertEqual(result, (baseURL.path as NSString).standardizingPath)
    }

    func testStopsAtNonCdCommand() {
        let result = OutputDirectoryChangeParser.resolveLeadingDirectoryChange(
            expandedCommand: "ls && cd Sub",
            currentDirectory: baseURL.path,
            previousDirectory: nil
        )
        XCTAssertNil(result)
    }

    func testCdDashUsesPreviousDirectory() throws {
        let previous = FileManager.default.temporaryDirectory
            .appendingPathComponent("meofind-cd-prev-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: previous, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: previous) }

        let result = OutputDirectoryChangeParser.resolveLeadingDirectoryChange(
            expandedCommand: "cd -",
            currentDirectory: baseURL.path,
            previousDirectory: previous.path
        )
        XCTAssertEqual(result, (previous.path as NSString).standardizingPath)
    }

    func testReturnsNilForMissingDirectory() {
        let result = OutputDirectoryChangeParser.resolveLeadingDirectoryChange(
            expandedCommand: "cd definitely-not-a-real-directory-xyz",
            currentDirectory: baseURL.path,
            previousDirectory: nil
        )
        XCTAssertNil(result)
    }
}
