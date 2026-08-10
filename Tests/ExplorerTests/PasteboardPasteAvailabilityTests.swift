import AppKit
import XCTest
@testable import Explorer

@MainActor
final class PasteboardPasteAvailabilityTests: XCTestCase {
    func testCanPasteUsesCachedStateWithoutReReadingPasteboardForFiles() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("paste-availability-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let availability = PasteboardPasteAvailability.shared
        let sourceFile = destination.appendingPathComponent("source.txt")
        try Data("hello".utf8).write(to: sourceFile)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([sourceFile as NSURL])

        availability.refreshNow()

        XCTAssertTrue(availability.canPaste(to: destination))
        XCTAssertEqual(availability.cachedState?.urls.count, 1)
        XCTAssertTrue(availability.cutItemPaths.isEmpty)
    }

    func testCutItemPathsPopulatedOnlyWhenPasteboardIsCut() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("paste-cut-paths-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        let sourceFile = destination.appendingPathComponent("cut-me.txt")
        try Data("hello".utf8).write(to: sourceFile)

        let availability = PasteboardPasteAvailability.shared
        let item = FileItem(
            id: sourceFile.path,
            url: sourceFile,
            name: sourceFile.lastPathComponent,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 5,
            isHidden: false,
            fileType: "txt",
            sizeDisplay: "5",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )

        FileOperations.cut([item])
        availability.refreshNow()
        XCTAssertFalse(availability.cutItemPaths.isEmpty)
        XCTAssertTrue(
            availability.cutItemPaths.contains(sourceFile.path)
                || availability.cutItemPaths.contains(sourceFile.standardizedFileURL.path)
        )

        FileOperations.copy([item])
        availability.refreshNow()
        XCTAssertTrue(availability.cutItemPaths.isEmpty)
    }

    func testCanPasteWithExplicitStateAvoidsSecondPasteboardRead() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("paste-state-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let sourceFile = destination.appendingPathComponent("source.txt")
        try Data("hello".utf8).write(to: sourceFile)
        let state = FileOperations.PasteboardState(urls: [sourceFile], isCut: false)

        XCTAssertTrue(
            FileOperations.canPaste(with: state, to: destination, hasCreatableContent: false)
        )
    }
}
