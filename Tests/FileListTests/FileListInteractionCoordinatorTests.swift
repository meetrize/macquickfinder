import XCTest
import AppKit
@testable import FileList

final class FileListInteractionCoordinatorTests: XCTestCase {
    func testQuickSearchAcceptsLettersAndDigits() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )
        XCTAssertEqual(FileListInteractionCoordinator.quickSearchInputCharacter(from: event!), "a")
    }

    func testQuickSearchRejectsWhitespace() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49
        )
        XCTAssertNil(FileListInteractionCoordinator.quickSearchInputCharacter(from: event!))
    }

    func testQuickSearchRejectsFunctionKeys() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "\u{F700}",
            isARepeat: false,
            keyCode: 122
        )
        XCTAssertNil(FileListInteractionCoordinator.quickSearchInputCharacter(from: event!))
    }
}
