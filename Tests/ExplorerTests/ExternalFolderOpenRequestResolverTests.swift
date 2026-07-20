import XCTest
@testable import Explorer

final class ExternalFolderOpenRequestResolverTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func testResolveOpensDirectory() throws {
        let folder = temporaryDirectory.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let resolved = ExternalFolderOpenRequestResolver.resolve(from: [folder])

        XCTAssertEqual(resolved?.directoryPath, folder.standardizedFileURL.path)
        XCTAssertNil(resolved?.selectionPath)
    }

    func testResolveSelectsFileInParentDirectory() throws {
        let file = temporaryDirectory.appendingPathComponent("note.txt")
        try Data("hello".utf8).write(to: file)

        let resolved = ExternalFolderOpenRequestResolver.resolve(from: [file])

        XCTAssertEqual(resolved?.directoryPath, temporaryDirectory.standardizedFileURL.path)
        XCTAssertEqual(resolved?.selectionPath, file.standardizedFileURL.path)
    }

    func testResolveFallsBackWhenPathIsUnreachable() {
        let missingFile = temporaryDirectory
            .appendingPathComponent("missing")
            .appendingPathComponent("file.txt")

        let resolved = ExternalFolderOpenRequestResolver.resolve(from: [missingFile])

        XCTAssertEqual(
            resolved?.directoryPath,
            missingFile.deletingLastPathComponent().standardizedFileURL.path
        )
        XCTAssertEqual(resolved?.selectionPath, missingFile.standardizedFileURL.path)
    }

    func testResolvePathTextSelectsFileAndOpensParent() throws {
        let file = temporaryDirectory.appendingPathComponent("deck.pptx")
        try Data("pptx".utf8).write(to: file)

        let resolved = ExternalFolderOpenRequestResolver.resolve(fromPathText: file.path)

        XCTAssertEqual(resolved?.directoryPath, temporaryDirectory.standardizedFileURL.path)
        XCTAssertEqual(resolved?.selectionPath, file.standardizedFileURL.path)
    }

    func testResolvePathTextStripsQuotesAndExpandsTildeForDirectory() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let resolved = ExternalFolderOpenRequestResolver.resolve(fromPathText: "\"~/\"")

        XCTAssertEqual(resolved?.directoryPath, (home as NSString).standardizingPath)
        XCTAssertNil(resolved?.selectionPath)
    }

    func testResolvePathTextOpensDirectory() throws {
        let folder = temporaryDirectory.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let resolved = ExternalFolderOpenRequestResolver.resolve(fromPathText: "  \(folder.path)  ")

        XCTAssertEqual(resolved?.directoryPath, folder.standardizedFileURL.path)
        XCTAssertNil(resolved?.selectionPath)
    }
}
