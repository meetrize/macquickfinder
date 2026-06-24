import XCTest
@testable import Explorer

final class OutputStreamCoalescerTests: XCTestCase {
    @MainActor
    func testCoalescesChunksBeforeFlush() async {
        let store = JobStore.shared
        store.removeAllJobs()

        let jobID = store.createJob(
            snippetName: "Coalesce",
            displayCommand: "echo",
            source: .snippet(id: UUID(), name: "Coalesce")
        )

        await OutputStreamCoalescer.shared.enqueue(jobID: jobID, stdout: "a")
        await OutputStreamCoalescer.shared.enqueue(jobID: jobID, stdout: "b")
        await OutputStreamCoalescer.shared.enqueue(jobID: jobID, stdout: "c")

        let beforeFlush = store.jobs.first { $0.id == jobID }?.stdout ?? ""
        XCTAssertEqual(beforeFlush, "")

        await OutputStreamCoalescer.shared.flushNow(jobID: jobID)

        let afterFlush = store.jobs.first { $0.id == jobID }?.stdout ?? ""
        XCTAssertEqual(afterFlush, "abc")
    }

    @MainActor
    func testAppendOutputTerminatesProcessWhenTruncated() async {
        let store = JobStore.shared
        store.removeAllJobs()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["60"]
        try? process.run()

        let jobID = store.createJob(
            snippetName: "Flood",
            displayCommand: "yes",
            source: .snippet(id: UUID(), name: "Flood")
        )
        store.markRunning(jobID: jobID, process: process)

        let limit = OutputStreamLimiter.maxCharactersPerJob
        let oversized = String(repeating: "x", count: limit + 1)
        store.appendOutput(jobID: jobID, stdout: oversized)

        let job = store.jobs.first { $0.id == jobID }
        XCTAssertEqual(job?.outputTruncated, true)

        for _ in 0..<30 where process.isRunning {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(process.isRunning)
    }
}
