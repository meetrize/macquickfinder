import XCTest
import AppKit
@testable import FileList

final class FileListInteractionCoordinatorTests_ContentSearch: XCTestCase {
    func testQuickSearchIgnoredWhenContentSearchActive() {
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
        )!

        var inputReceived = false
        let interaction = FileListTableInteraction(
            isContentSearchActive: true,
            onQuickSearchInput: { _ in inputReceived = true }
        )

        let handled = FileListInteractionCoordinator.handleQuickSearchKeys(
            event: event,
            interaction: interaction,
            effectiveSelectionIDs: { [] }
        )

        XCTAssertFalse(handled)
        XCTAssertFalse(inputReceived)
    }
}
