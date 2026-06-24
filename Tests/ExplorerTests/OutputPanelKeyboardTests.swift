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

    func testControlCInterruptsWhenEnabled() {
        let event = keyDown(characters: "c", modifiers: .control)
        XCTAssertEqual(
            OutputPanelKeyboard.action(for: event, isFindActive: false, isInterruptEnabled: true),
            .interrupt
        )
    }

    func testControlCDoesNotInterruptWhenDisabled() {
        let event = keyDown(characters: "c", modifiers: .control)
        XCTAssertNil(
            OutputPanelKeyboard.action(for: event, isFindActive: false, isInterruptEnabled: false)
        )
    }

    func testCommandFFindWhenActive() {
        let event = keyDown(characters: "f", modifiers: .command)
        XCTAssertEqual(
            OutputPanelKeyboard.action(for: event, isFindActive: true, isInterruptEnabled: false),
            .find
        )
    }

    func testCommandFIgnoredWhenInactive() {
        let event = keyDown(characters: "f", modifiers: .command)
        XCTAssertNil(
            OutputPanelKeyboard.action(for: event, isFindActive: false, isInterruptEnabled: false)
        )
    }

    func testInterruptTakesPrecedenceOverFind() {
        let event = keyDown(characters: "c", modifiers: [.control, .command])
        XCTAssertNil(
            OutputPanelKeyboard.action(for: event, isFindActive: true, isInterruptEnabled: true)
        )
    }
}
