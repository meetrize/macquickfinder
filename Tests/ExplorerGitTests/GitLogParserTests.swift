import XCTest
@testable import Explorer

final class GitLogParserTests: XCTestCase {
    func testParseZTerminatedLogRecords() {
        let sep = "\u{1f}"
        let payload = "fullhash1234567890\(sep)fullha\(sep)feat: add git history\(sep)3 days ago\0"
        let commits = GitLogParser.parse(zTerminated: Data(payload.utf8))

        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits[0].fullHash, "fullhash1234567890")
        XCTAssertEqual(commits[0].shortHash, "fullha")
        XCTAssertEqual(commits[0].subject, "feat: add git history")
        XCTAssertEqual(commits[0].relativeDate, "3 days ago")
    }

    func testParseEmptyPayload() {
        XCTAssertTrue(GitLogParser.parse(zTerminated: Data()).isEmpty)
    }
}
