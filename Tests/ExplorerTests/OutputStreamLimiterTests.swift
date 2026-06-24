import XCTest
@testable import Explorer

final class OutputStreamLimiterTests: XCTestCase {
    func testAppendsWithinLimit() {
        var stdout = "hello"
        var stderr = ""
        var truncated = false

        let accepted = OutputStreamLimiter.append(
            stdout: &stdout,
            stderr: &stderr,
            truncated: &truncated,
            stdoutChunk: " world",
            stderrChunk: nil,
            truncationNotice: "TRUNC"
        )

        XCTAssertTrue(accepted)
        XCTAssertFalse(truncated)
        XCTAssertEqual(stdout, "hello world")
    }

    func testTruncatesAndMarksWhenExceedingLimit() {
        var stdout = ""
        var stderr = ""
        var truncated = false
        let limit = OutputStreamLimiter.maxCharactersPerJob
        let notice = "TRUNC"
        let noticeLength = notice.count + 1
        let oversized = String(repeating: "x", count: limit - noticeLength + 10)

        let accepted = OutputStreamLimiter.append(
            stdout: &stdout,
            stderr: &stderr,
            truncated: &truncated,
            stdoutChunk: oversized,
            stderrChunk: nil,
            truncationNotice: notice
        )

        XCTAssertFalse(accepted)
        XCTAssertTrue(truncated)
        XCTAssertEqual(stdout.count + stderr.count, limit)
        XCTAssertTrue(stderr.contains(notice))
    }

    func testIgnoresFurtherAppendsAfterTruncated() {
        var stdout = "x"
        var stderr = ""
        var truncated = true

        let accepted = OutputStreamLimiter.append(
            stdout: &stdout,
            stderr: &stderr,
            truncated: &truncated,
            stdoutChunk: "more",
            stderrChunk: nil,
            truncationNotice: "TRUNC"
        )

        XCTAssertFalse(accepted)
        XCTAssertEqual(stdout, "x")
    }
}
