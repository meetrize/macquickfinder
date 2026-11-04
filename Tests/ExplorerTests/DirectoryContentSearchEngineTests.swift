import XCTest
@testable import Explorer

final class DirectoryContentSearchEngineTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("content-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    func testScanFindsMatchesAcrossFiles() async throws {
        let fileA = tempDirectory.appendingPathComponent("A.swift")
        let fileB = tempDirectory.appendingPathComponent("B.md")
        try "let todo = 1\n// TODO fix".write(to: fileA, atomically: true, encoding: .utf8)
        try "# TODO heading".write(to: fileB, atomically: true, encoding: .utf8)

        let engine = DirectoryContentSearchEngine()
        let request = ContentSearchRequest(
            root: tempDirectory,
            query: "TODO",
            filter: .default,
            showHiddenFiles: false,
            generation: 1
        )

        let result = await engine.runSearch(request: request, isCancelled: { false })
        XCTAssertEqual(result.matches.count, 3)
        XCTAssertTrue(result.progress.isComplete)
    }

    func testIncludeGlobRestrictsFiles() async throws {
        let swiftFile = tempDirectory.appendingPathComponent("A.swift")
        let mdFile = tempDirectory.appendingPathComponent("B.md")
        try "// TODO".write(to: swiftFile, atomically: true, encoding: .utf8)
        try "TODO".write(to: mdFile, atomically: true, encoding: .utf8)

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
        XCTAssertEqual(result.matches.first?.fileURL.lastPathComponent, "A.swift")
    }

    func testMaxMatchCountTruncates() async throws {
        let file = tempDirectory.appendingPathComponent("Many.swift")
        try String(repeating: "TODO\n", count: 20).write(to: file, atomically: true, encoding: .utf8)

        var filter = ContentSearchFilter.default
        filter.maxMatchCount = 5

        let engine = DirectoryContentSearchEngine()
        let request = ContentSearchRequest(
            root: tempDirectory,
            query: "TODO",
            filter: filter,
            showHiddenFiles: false,
            generation: 1
        )

        let result = await engine.runSearch(request: request, isCancelled: { false })
        XCTAssertEqual(result.matches.count, 5)
        XCTAssertTrue(result.progress.wasTruncated)
    }

    func testCancellationStopsScan() async throws {
        let subdir = tempDirectory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        for index in 0..<50 {
            let file = subdir.appendingPathComponent("file\(index).swift")
            try "TODO \(index)".write(to: file, atomically: true, encoding: .utf8)
        }

        let engine = DirectoryContentSearchEngine()
        let request = ContentSearchRequest(
            root: tempDirectory,
            query: "TODO",
            filter: .default,
            showHiddenFiles: false,
            generation: 1
        )

        var cancelled = false
        let result = await engine.runSearch(request: request, isCancelled: { cancelled })
        cancelled = true
        _ = result
        // Re-run with immediate cancel
        let cancelledResult = await engine.runSearch(request: request, isCancelled: { true })
        XCTAssertTrue(cancelledResult.progress.wasCancelled)
    }

    func testLongLineMatchStoresBoundedSnippet() async throws {
        let file = tempDirectory.appendingPathComponent("minified.js")
        let prefix = String(repeating: "a", count: 2_500)
        let suffix = String(repeating: "b", count: 2_500)
        try "\(prefix)TODO\(suffix)".write(to: file, atomically: true, encoding: .utf8)

        let matches = ContentSearchFileScanner.scanFileContents(
            url: file,
            relativePath: "minified.js",
            query: "TODO",
            filter: .default
        )

        let match = try XCTUnwrap(matches.first)
        XCTAssertLessThanOrEqual(match.lineText.utf16.count, ContentSearchFileScanner.maxSnippetUTF16Length + 4)
        XCTAssertTrue(match.lineText.contains("TODO"))
        XCTAssertEqual(match.lineColumnUTF16, 2_500)

        let snippetText = match.lineText as NSString
        let highlighted = snippetText.substring(with: NSRange(location: match.matchStartUTF16, length: match.matchLengthUTF16))
        XCTAssertEqual(highlighted, "TODO")
    }

    func testExcludedDirectoriesAreNotScanned() async throws {
        let nested = tempDirectory.appendingPathComponent("node_modules/pkg", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "// TODO excluded".write(
            to: nested.appendingPathComponent("index.js"),
            atomically: true,
            encoding: .utf8
        )
        try "// TODO included".write(
            to: tempDirectory.appendingPathComponent("app.swift"),
            atomically: true,
            encoding: .utf8
        )

        let engine = DirectoryContentSearchEngine()
        let request = ContentSearchRequest(
            root: tempDirectory,
            query: "TODO",
            filter: .default,
            showHiddenFiles: false,
            generation: 1
        )

        let result = await engine.runSearch(request: request, isCancelled: { false })
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first?.fileURL.lastPathComponent, "app.swift")
    }

    func testSkipsBinaryNULFile() async throws {
        let file = tempDirectory.appendingPathComponent("binary.txt")
        var data = Data("TODO before".utf8)
        data.append(0)
        data.append(contentsOf: "after".utf8)
        try data.write(to: file)

        let engine = DirectoryContentSearchEngine()
        let matches = await engine.scanFile(
            url: file,
            relativePath: "binary.txt",
            query: "TODO",
            filter: .default
        )
        XCTAssertTrue(matches.isEmpty)
    }

    func testScannerSkipsBinaryNULFile() throws {
        let file = tempDirectory.appendingPathComponent("binary.txt")
        var data = Data("TODO before".utf8)
        data.append(0)
        data.append(contentsOf: "after".utf8)
        try data.write(to: file)

        let matches = ContentSearchFileScanner.scanFileContents(
            url: file,
            relativePath: "binary.txt",
            query: "TODO",
            filter: .default
        )
        XCTAssertTrue(matches.isEmpty)
    }
}
