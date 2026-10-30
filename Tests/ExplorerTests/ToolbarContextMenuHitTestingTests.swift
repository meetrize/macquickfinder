import AppKit
import XCTest
@testable import Explorer

final class ToolbarContextMenuHitTestingTests: XCTestCase {
    func testEditableTextFieldIsRecognized() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        field.isEditable = true
        XCTAssertTrue(ToolbarContextMenuHitTesting.isInsideEditableText(field))
    }

    func testNonEditableLabelIsNotEditableText() {
        let label = NSTextField(labelWithString: "Browse Settings")
        XCTAssertFalse(ToolbarContextMenuHitTesting.isInsideEditableText(label))
    }

    func testDescendantOfEditableFieldIsRecognized() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        field.isEditable = true
        let child = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        field.addSubview(child)
        XCTAssertTrue(ToolbarContextMenuHitTesting.isInsideEditableText(child))
    }
}
