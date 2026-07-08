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
