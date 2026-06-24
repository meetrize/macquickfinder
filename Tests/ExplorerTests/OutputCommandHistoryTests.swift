import XCTest
@testable import Explorer

final class OutputCommandHistoryTests: XCTestCase {
    func testRecordSkipsConsecutiveDuplicates() {
        var history = OutputCommandHistory()
        history.record("ls")
        history.record("ls")
        XCTAssertEqual(history.entries, ["ls"])
    }

    func testStepUpAndDownThroughHistory() {
        var history = OutputCommandHistory()
        history.record("first")
        history.record("second")

        XCTAssertEqual(history.step(.up, currentDraft: ""), "second")
        XCTAssertEqual(history.step(.up, currentDraft: ""), "first")
        XCTAssertNil(history.step(.up, currentDraft: ""))

        XCTAssertEqual(history.step(.down, currentDraft: ""), "second")
        XCTAssertEqual(history.step(.down, currentDraft: ""), "")
    }

    func testStepUpPreservesDraftBeforeBrowse() {
        var history = OutputCommandHistory()
        history.record("ls")

        XCTAssertEqual(history.step(.up, currentDraft: "draft"), "ls")
        XCTAssertEqual(history.step(.down, currentDraft: "draft"), "draft")
    }

    func testTrimsOldestWhenExceedingCapacity() {
        var history = OutputCommandHistory()
        for index in 0..<(OutputCommandHistory.defaultCapacity + 5) {
            history.record("cmd\(index)")
        }
        XCTAssertEqual(history.entries.count, OutputCommandHistory.defaultCapacity)
        XCTAssertEqual(history.entries.first, "cmd5")
        XCTAssertEqual(history.entries.last, "cmd104")
    }
}
