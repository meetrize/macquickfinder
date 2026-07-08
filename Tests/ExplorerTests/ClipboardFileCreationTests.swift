import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import Explorer

final class ClipboardFileCreationTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-file-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testIsMarkdownDetectsHeading() {
        XCTAssertTrue(ClipboardFileCreation.isMarkdown("# Title\n\nBody"))
    }

    func testIsMarkdownDetectsFencedCodeBlock() {
        XCTAssertTrue(ClipboardFileCreation.isMarkdown("""
        Some intro
        ```swift
        let x = 1
        ```
        """))
    }

    func testIsMarkdownDetectsLinkSyntax() {
        XCTAssertTrue(ClipboardFileCreation.isMarkdown("See [docs](https://example.com) for details."))
    }

    func testIsMarkdownDetectsFrontMatter() {
        XCTAssertTrue(ClipboardFileCreation.isMarkdown("""
        ---
        title: Hello
        ---

        Content
        """))
    }

    func testPlainTextIsNotMarkdown() {
        XCTAssertFalse(ClipboardFileCreation.isMarkdown("hello world"))
        XCTAssertFalse(ClipboardFileCreation.isMarkdown("just a sentence with #hashtag"))
    }

    func testSuggestedTextFileNameUsesTitleForMarkdown() {
        let fileName = ClipboardFileCreation.suggestedTextFileName(
            for: "# My Notes\n\nSome content",
            format: .markdown
        )
        XCTAssertEqual(fileName, "My Notes.md")
    }

    func testSuggestedTextFileNameUsesDefaultMarkdownName() {
        let fileName = ClipboardFileCreation.suggestedTextFileName(
            for: "",
            format: .markdown
        )
        XCTAssertEqual(fileName, L10n.File.pastedMarkdownFileName)
    }

    func testSuggestedTextFileNameUsesFirstLineForPlainText() {
        let fileName = ClipboardFileCreation.suggestedTextFileName(
            for: "plain notes",
            format: .plain
        )
        XCTAssertEqual(fileName, "plain notes.txt")
    }

    func testCreateFileFromMarkdownPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test-markdown-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("# Project Plan\n\n- step one", forType: .string)

        let createdURL = try XCTUnwrap(ClipboardFileCreation.createFile(in: tempDirectory, pasteboard: pasteboard))
        XCTAssertEqual(createdURL.pathExtension, "md")
        XCTAssertEqual(createdURL.lastPathComponent, "Project Plan.md")
        let contents = try String(contentsOf: createdURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("step one"))
    }

    func testCreateFileFromPlainTextPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test-text-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("plain notes", forType: .string)

        let createdURL = try XCTUnwrap(ClipboardFileCreation.createFile(in: tempDirectory, pasteboard: pasteboard))
        XCTAssertEqual(createdURL.pathExtension, "txt")
        XCTAssertEqual(createdURL.lastPathComponent, "plain notes.txt")
    }

    func testSuggestedImageFileNameUsesProperExtension() {
        let fileName = ClipboardFileCreation.suggestedImageFileName(fileExtension: "png")
        XCTAssertEqual(fileName, "\(L10n.File.pastedImageBaseName).png")
        XCTAssertTrue(fileName.hasSuffix(".png"))
        XCTAssertFalse(fileName.hasSuffix(".pasted_image_name"))
    }

    func testCreateFileFromImagePasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test-image-\(UUID().uuidString)"))
        pasteboard.clearContents()
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        pasteboard.writeObjects([image])

        let createdURL = try XCTUnwrap(ClipboardFileCreation.createFile(in: tempDirectory, pasteboard: pasteboard))
        XCTAssertEqual(createdURL.pathExtension, "png")
        XCTAssertEqual(createdURL.lastPathComponent, ClipboardFileCreation.suggestedImageFileName(fileExtension: "png"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: createdURL.path))
    }

    func testCreateFileFromJPEGPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test-jpeg-\(UUID().uuidString)"))
        pasteboard.clearContents()
        let jpegType = NSPasteboard.PasteboardType(UTType.jpeg.identifier)
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        pasteboard.setData(jpegData, forType: jpegType)

        let createdURL = try XCTUnwrap(ClipboardFileCreation.createFile(in: tempDirectory, pasteboard: pasteboard))
        XCTAssertEqual(createdURL.pathExtension, "jpg")
        XCTAssertEqual(createdURL.lastPathComponent, ClipboardFileCreation.suggestedImageFileName(fileExtension: "jpg"))
    }

    func testCreateFileFromTIFFPasteboardCompressesToPNG() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test-tiff-\(UUID().uuidString)"))
        pasteboard.clearContents()
        let image = NSImage(size: NSSize(width: 64, height: 64))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 64).fill()
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation else {
            XCTFail("Expected TIFF representation")
            return
        }
        pasteboard.setData(tiffData, forType: .tiff)

        let createdURL = try XCTUnwrap(ClipboardFileCreation.createFile(in: tempDirectory, pasteboard: pasteboard))
        XCTAssertEqual(createdURL.pathExtension, "png")
        let outputData = try Data(contentsOf: createdURL)
        XCTAssertTrue(outputData.starts(with: Data([0x89, 0x50, 0x4E, 0x47])))
        XCTAssertLessThan(outputData.count, tiffData.count)
    }

    func testCanCreateFileReturnsFalseInTrash() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("test-trash-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)

        XCTAssertFalse(
            ClipboardFileCreation.canCreateFile(
                in: URL(fileURLWithPath: TrashLoader.userTrashPath, isDirectory: true),
                pasteboard: pasteboard
            )
        )
    }
}
