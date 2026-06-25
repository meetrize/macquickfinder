import XCTest
@testable import Explorer
import AppKit

final class OutputPanelKeyboardTests: XCTestCase {
    private func keyDown(
        characters: String,
        modifiers: NSEvent.ModifierFlags
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
            keyCode: 0
        )!
    }

    private func action(
        for event: NSEvent,
        isFindActive: Bool = false,
        isCommandFieldFocused: Bool = false,
        isInterruptEnabled: Bool = false
    ) -> OutputPanelKeyboardAction? {
        OutputPanelKeyboard.action(
            for: event,
            isFindActive: isFindActive,
            isCommandFieldFocused: isCommandFieldFocused,
            isInterruptEnabled: isInterruptEnabled
        )
    }

    func testControlCInterruptsWhenEnabled() {
        let event = keyDown(characters: "c", modifiers: .control)
        XCTAssertEqual(action(for: event, isInterruptEnabled: true), .interrupt)
    }

    func testControlCDoesNotInterruptWhenDisabled() {
        let event = keyDown(characters: "c", modifiers: .control)
        XCTAssertNil(action(for: event, isInterruptEnabled: false))
    }

    func testControlCIgnoredWhenCommandFieldFocused() {
        let event = keyDown(characters: "c", modifiers: .control)
        XCTAssertNil(action(for: event, isCommandFieldFocused: true, isInterruptEnabled: true))
    }

    func testCommandFFindWhenActive() {
        let event = keyDown(characters: "f", modifiers: .command)
        XCTAssertEqual(action(for: event, isFindActive: true), .find)
    }

    func testCommandFIgnoredWhenInactive() {
        let event = keyDown(characters: "f", modifiers: .command)
        XCTAssertNil(action(for: event, isFindActive: false))
    }

    func testInterruptTakesPrecedenceOverFind() {
        let event = keyDown(characters: "c", modifiers: [.control, .command])
        XCTAssertNil(action(for: event, isFindActive: true, isInterruptEnabled: true))
    }
}
