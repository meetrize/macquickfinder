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

    func testQuickSearchAcceptsPeriod() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: ".",
            charactersIgnoringModifiers: ".",
            isARepeat: false,
            keyCode: 47
        )
        XCTAssertEqual(FileListInteractionCoordinator.quickSearchInputCharacter(from: event!), ".")
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

    func testNextQuickSearchMatchIndexCyclesForward() {
        let matches = [2, 5, 9]
        XCTAssertEqual(
            FileListInteractionCoordinator.nextQuickSearchMatchIndex(in: matches, from: 2, forward: true),
            5
        )
        XCTAssertEqual(
            FileListInteractionCoordinator.nextQuickSearchMatchIndex(in: matches, from: 9, forward: true),
            2
        )
    }

    func testNextQuickSearchMatchIndexCyclesBackward() {
        let matches = [2, 5, 9]
        XCTAssertEqual(
            FileListInteractionCoordinator.nextQuickSearchMatchIndex(in: matches, from: 5, forward: false),
            2
        )
        XCTAssertEqual(
            FileListInteractionCoordinator.nextQuickSearchMatchIndex(in: matches, from: 2, forward: false),
            9
        )
    }

    func testNextQuickSearchMatchIndexStartsFromEndsWhenCurrentNotInMatches() {
        let matches = [2, 5, 9]
        XCTAssertEqual(
            FileListInteractionCoordinator.nextQuickSearchMatchIndex(in: matches, from: 3, forward: true),
            2
        )
        XCTAssertEqual(
            FileListInteractionCoordinator.nextQuickSearchMatchIndex(in: matches, from: 3, forward: false),
            9
        )
    }
}
