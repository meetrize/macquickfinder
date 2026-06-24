import XCTest
@testable import Explorer

final class StreamProgressOutputTests: XCTestCase {
    func testAugmentGitCloneAddsProgress() {
        let command = "git clone https://github.com/meetrize/KLineChart.git"
        XCTAssertEqual(
            ShellCommandProgressSupport.augment(command),
            "git clone --progress https://github.com/meetrize/KLineChart.git"
        )
    }

    func testAugmentGitCloneSkipsWhenProgressPresent() {
        let command = "git clone --progress https://github.com/example/repo.git"
        XCTAssertEqual(ShellCommandProgressSupport.augment(command), command)
    }

    func testAugmentGitCloneSkipsQuiet() {
        let command = "git clone --quiet https://github.com/example/repo.git"
        XCTAssertEqual(ShellCommandProgressSupport.augment(command), command)
    }

    func testAugmentLeavesOtherCommandsUntouched() {
        let command = "ls -la"
        XCTAssertEqual(ShellCommandProgressSupport.augment(command), command)
    }

    func testCarriageReturnKeepsLatestProgressLine() {
        let input = "\rReceiving objects:  10%\rReceiving objects:  50%"
        XCTAssertEqual(
            StreamProgressOutput.applyCarriageReturns(input),
            "Receiving objects:  50%"
        )
    }

    func testIngestCommitsCompletedLinesAndKeepsPendingTail() {
        var state = StreamProgressOutput.StreamState()
        let committed = StreamProgressOutput.ingest(
            chunk: "remote: done.\n\rReceiving objects:  12%",
            state: &state
        )
        XCTAssertEqual(committed, "remote: done.\n")
        XCTAssertEqual(state.pending, "Receiving objects:  12%")
    }

    func testIngestUpdatesPendingProgressAcrossChunks() {
        var state = StreamProgressOutput.StreamState()
        _ = StreamProgressOutput.ingest(chunk: "\rReceiving objects:  12%", state: &state)
        let committed = StreamProgressOutput.ingest(chunk: "\rReceiving objects:  88%\n", state: &state)
        XCTAssertEqual(committed, "Receiving objects:  88%\n")
        XCTAssertTrue(state.pending.isEmpty)
    }
}
