import XCTest
@testable import Explorer

final class OutputCommandCompleterTests: XCTestCase {
    func testLongestCommonPrefixCompletion() {
        var session = OutputCommandCompletionSession()
        let request = OutputCommandCompletionRequest(
            line: "gi",
            cursor: 2,
            cwd: "/tmp"
        )
        let result = OutputCommandCompleter.complete(
            request: request,
            session: &session,
            candidatesProvider: { _, _, _ in
                ["git", "gitx", "gitbar"]
            }
        )
        XCTAssertEqual(result?.line, "git")
        XCTAssertEqual(result?.cursor, 3)
    }

    func testCyclesCandidatesOnRepeatedTab() {
        var session = OutputCommandCompletionSession()
        let provider: OutputCommandCompleter.CandidatesProvider = { _, _, _ in
            ["alpha", "beta"]
        }
        let request = OutputCommandCompletionRequest(line: "a", cursor: 1, cwd: "/tmp")

        let first = OutputCommandCompleter.complete(
            request: request,
            session: &session,
            candidatesProvider: provider
        )
        XCTAssertEqual(first?.line, "alpha")

        let second = OutputCommandCompleter.complete(
            request: OutputCommandCompletionRequest(line: first!.line, cursor: first!.cursor, cwd: "/tmp"),
            session: &session,
            candidatesProvider: provider
        )
        XCTAssertEqual(second?.line, "beta")
    }

    func testWordParserFindsLastToken() {
        let line = "ls -la /tmp/a"
        let word = OutputCommandWordParser.currentWord(in: line, cursor: line.count)
        XCTAssertEqual(word, "/tmp/a")
    }

    func testLongestCommonPrefixHelper() {
        XCTAssertEqual(
            OutputCommandCompleter.longestCommonPrefix(in: ["git", "gist", "gifsicle"]),
            "gi"
        )
    }
}
