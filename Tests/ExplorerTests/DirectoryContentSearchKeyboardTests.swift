import XCTest
@testable import Explorer

final class DirectoryContentSearchKeyboardTests: XCTestCase {
    func testArrowDownMovesSelectionForward() {
        let event = keyEvent(keyCode: 125)
        XCTAssertEqual(DirectoryContentSearchKeyboard.action(for: event), .moveSelection(forward: true))
    }

    func testCommandGFindsNext() {
        let event = keyEvent(keyCode: 5, modifiers: .command, characters: "g")
        XCTAssertEqual(DirectoryContentSearchKeyboard.action(for: event), .findNext)
    }

    func testEscapeDismisses() {
        let event = keyEvent(keyCode: 53)
        XCTAssertEqual(DirectoryContentSearchKeyboard.action(for: event), .dismiss)
    }

    private func keyEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        characters: String = ""
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}
