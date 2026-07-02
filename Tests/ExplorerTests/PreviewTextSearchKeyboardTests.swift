import AppKit
import XCTest
@testable import Explorer

final class PreviewTextSearchKeyboardTests: XCTestCase {
    private func action(
        keyCode: UInt16,
        characters: String? = nil,
        command: Bool = false,
        shift: Bool = false
    ) -> PreviewTextSearchKeyboardAction? {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [
                command ? .command : [],
                shift ? .shift : [],
            ],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )
        guard let event else {
            XCTFail("failed to create NSEvent")
            return nil
        }
        return PreviewTextSearchKeyboard.action(for: event)
    }

    func testCommandGFindNext() {
        XCTAssertEqual(action(keyCode: 5, characters: "g", command: true), .findNext)
    }

    func testCommandShiftGFindPrevious() {
        XCTAssertEqual(action(keyCode: 5, characters: "g", command: true, shift: true), .findPrevious)
    }

    func testEscapeClearsSearch() {
        XCTAssertEqual(action(keyCode: 53), .clear)
    }

    func testPlainGIsIgnored() {
        XCTAssertNil(action(keyCode: 5, characters: "g"))
    }
}
