import XCTest
@testable import Explorer

final class OutputRunningDisplayBufferTests: XCTestCase {
    func testTrimPreservesTail() {
        var stdout = String(repeating: "a", count: OutputRunningDisplayBuffer.maxCharacters + 500)
        OutputRunningDisplayBuffer.trimPreservingTail(&stdout)

        XCTAssertLessThanOrEqual(stdout.count, OutputRunningDisplayBuffer.maxCharacters)
        XCTAssertTrue(stdout.hasSuffix(String(repeating: "a", count: 500)))
        XCTAssertTrue(stdout.contains("…"))
    }

    func testNoTrimWhenUnderLimit() {
        var stdout = "hello"
        OutputRunningDisplayBuffer.trimPreservingTail(&stdout)
        XCTAssertEqual(stdout, "hello")
    }
}
