import AppKit
import XCTest
@testable import Explorer

final class ClipboardPathResolverTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var pasteboard: NSPasteboard!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        pasteboard = NSPasteboard.withUniqueName()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        pasteboard = nil
    }

    func testLooksLikePathAcceptsAbsoluteTildeAndFileURL() {
        XCTAssertTrue(ClipboardPathResolver.looksLikePath("/Users/demo"))
        XCTAssertTrue(ClipboardPathResolver.looksLikePath("~/Desktop"))
        XCTAssertTrue(ClipboardPathResolver.looksLikePath("\"~/Documents\""))
        XCTAssertTrue(ClipboardPathResolver.looksLikePath("file:///tmp"))
        XCTAssertFalse(ClipboardPathResolver.looksLikePath("hello world"))
        XCTAssertFalse(ClipboardPathResolver.looksLikePath(""))
    }

    func testResolveDirectoryFromString() throws {
        let folder = temporaryDirectory.appendingPathComponent("Docs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        pasteboard.clearContents()
        pasteboard.setString(folder.path, forType: .string)

        let resolved = ClipboardPathResolver.resolve(pasteboard: pasteboard)

        XCTAssertEqual(resolved?.directoryPath, folder.standardizedFileURL.path)
        XCTAssertNil(resolved?.selectionPath)
    }

    func testResolveQuotedDirectoryPath() throws {
        let folder = temporaryDirectory.appendingPathComponent("Quoted", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        pasteboard.clearContents()
        pasteboard.setString("\"\(folder.path)\"", forType: .string)

        let resolved = ClipboardPathResolver.resolve(pasteboard: pasteboard)

        XCTAssertEqual(resolved?.directoryPath, folder.standardizedFileURL.path)
    }

    func testResolveUsesFirstLineOnly() throws {
        let folder = temporaryDirectory.appendingPathComponent("LineOne", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        pasteboard.clearContents()
        pasteboard.setString("\(folder.path)\n/second/line", forType: .string)

        let resolved = ClipboardPathResolver.resolve(pasteboard: pasteboard)

        XCTAssertEqual(resolved?.directoryPath, folder.standardizedFileURL.path)
    }

    func testResolveSelectsFileInParent() throws {
        let file = temporaryDirectory.appendingPathComponent("note.txt")
        try Data("hi".utf8).write(to: file)
        pasteboard.clearContents()
        pasteboard.setString(file.path, forType: .string)

        let resolved = ClipboardPathResolver.resolve(pasteboard: pasteboard)

        XCTAssertEqual(resolved?.directoryPath, temporaryDirectory.standardizedFileURL.path)
        XCTAssertEqual(resolved?.selectionPath, file.standardizedFileURL.path)
    }

    func testResolveIgnoresPlainSentence() {
        pasteboard.clearContents()
        pasteboard.setString("just a sentence", forType: .string)

        XCTAssertNil(ClipboardPathResolver.resolve(pasteboard: pasteboard))
    }

    func testResolveIgnoresMissingAbsolutePath() {
        pasteboard.clearContents()
        pasteboard.setString("/tmp/meofind-missing-\(UUID().uuidString)", forType: .string)

        XCTAssertNil(ClipboardPathResolver.resolve(pasteboard: pasteboard))
    }

    func testResolveFromFileURLPasteboard() throws {
        let folder = temporaryDirectory.appendingPathComponent("FromURL", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        pasteboard.clearContents()
        pasteboard.writeObjects([folder as NSURL])

        let resolved = ClipboardPathResolver.resolve(pasteboard: pasteboard)

        XCTAssertEqual(resolved?.directoryPath, folder.standardizedFileURL.path)
    }
}
