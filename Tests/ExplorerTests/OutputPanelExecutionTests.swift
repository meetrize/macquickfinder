import XCTest
@testable import Explorer
import FileList

@MainActor
final class OutputPanelExecutionTests: XCTestCase {
    override func tearDown() {
        JobStore.shared.removeAllJobs()
        super.tearDown()
    }

    private func makeFileItem(id: String = "/tmp/a.txt") -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: id),
            name: (id as NSString).lastPathComponent,
            isDirectory: false,
            modificationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "txt",
            sizeDisplay: "0 B",
            dateDisplay: ""
        )
    }

    func testExecuteInPlaceAppendsPromptAndReusesJob() {
        let store = JobStore.shared
        store.removeAllJobs()

        let jobID = store.createJob(
            snippetName: "Test",
            displayCommand: "echo hi",
            source: .snippet(id: UUID(), name: "Test"),
            expandedContent: "echo hi",
            workingDirectory: "/tmp/old"
        )
        store.appendOutput(jobID: jobID, stdout: "first\n")

        let context = OutputExecutionContext(
            cwd: "/Users/me/Projects",
            selectedItems: [],
            showHiddenFiles: false
        )
        store.executeInPlace(jobID: jobID, rawCommand: "echo %d", context: context)

        XCTAssertEqual(store.jobs.count, 1)
        let job = store.jobs.first { $0.id == jobID }
        XCTAssertNotNil(job)
        XCTAssertTrue(job?.stdout.contains("Projects $ echo %d") == true)
        XCTAssertEqual(job?.workingDirectory, "/Users/me/Projects")
    }

    func testExecuteInPlaceRejectsWhileRunning() {
        let store = JobStore.shared
        store.removeAllJobs()

        let jobID = store.createJob(
            snippetName: "Running",
            displayCommand: "sleep",
            source: .snippet(id: UUID(), name: "Running")
        )
        store.markRunning(jobID: jobID, process: Process())

        let before = store.jobs.first { $0.id == jobID }?.stdout ?? ""
        store.executeInPlace(
            jobID: jobID,
            rawCommand: "echo blocked",
            context: OutputExecutionContext(cwd: "/", selectedItems: [], showHiddenFiles: false)
        )
        let after = store.jobs.first { $0.id == jobID }?.stdout ?? ""
        XCTAssertEqual(before, after)
    }

    func testOutputSessionFormattingPrompt() {
        let prompt = OutputSessionFormatting.prompt(cwd: "/Users/me/Projects", command: "ls")
        XCTAssertTrue(prompt.contains("Projects $ ls"))
    }

    func testOutputSessionFormattingCompletionStatus() {
        XCTAssertEqual(OutputSessionFormatting.completionStatus(exitCode: 0), "\n✓\n")
        XCTAssertEqual(OutputSessionFormatting.completionStatus(exitCode: 2), "\n✗\n")
        XCTAssertEqual(OutputSessionFormatting.cancelledStatus(), "\n⊘\n")
    }

    func testMarkFinishedAppendsStatusLine() {
        let store = JobStore.shared
        store.removeAllJobs()

        let jobID = store.createJob(
            snippetName: "Test",
            displayCommand: "true",
            source: .snippet(id: UUID(), name: "Test")
        )
        store.markRunning(jobID: jobID, process: Process())
        store.markFinished(jobID: jobID, exitCode: 0)

        let job = store.jobs.first { $0.id == jobID }
        XCTAssertEqual(job?.status, .succeeded)
        XCTAssertTrue(job?.stdout.contains("\n✓\n") == true)
    }

    func testMarkFinishedIgnoresWhenAlreadyCancelled() {
        let store = JobStore.shared
        store.removeAllJobs()

        let jobID = store.createJob(
            snippetName: "Test",
            displayCommand: "sleep",
            source: .snippet(id: UUID(), name: "Test")
        )
        store.markRunning(jobID: jobID, process: Process())
        store.cancel(jobID: jobID)
        let stdoutAfterCancel = store.jobs.first { $0.id == jobID }?.stdout ?? ""

        store.markFinished(jobID: jobID, exitCode: 15)

        let job = store.jobs.first { $0.id == jobID }
        XCTAssertEqual(job?.status, .cancelled)
        XCTAssertEqual(job?.stdout, stdoutAfterCancel)
        XCTAssertTrue(job?.stdout.contains("\n⊘\n") == true)
    }

    func testCancelMarksJobCancelled() {
        let store = JobStore.shared
        store.removeAllJobs()

        let jobID = store.createJob(
            snippetName: "Running",
            displayCommand: "sleep",
            source: .snippet(id: UUID(), name: "Running")
        )
        store.markRunning(jobID: jobID, process: Process())

        store.cancel(jobID: jobID)

        let job = store.jobs.first { $0.id == jobID }
        XCTAssertEqual(job?.status, .cancelled)
        XCTAssertNotNil(job?.endedAt)
        XCTAssertTrue(job?.stdout.contains("\n⊘\n") == true)
    }

    func testAppendOutputInlinesStderrIntoStdout() {
        let store = JobStore.shared
        store.removeAllJobs()

        let jobID = store.createJob(
            snippetName: "Test",
            displayCommand: "cd bad",
            source: .snippet(id: UUID(), name: "Test")
        )
        store.appendOutput(jobID: jobID, stdout: OutputSessionFormatting.prompt(cwd: "/tmp", command: "cd bad"))
        store.appendOutput(jobID: jobID, stderr: "cd: no such file\n")
        store.appendOutput(jobID: jobID, stdout: OutputSessionFormatting.completionStatus(exitCode: 1))
        store.appendOutput(jobID: jobID, stdout: OutputSessionFormatting.prompt(cwd: "/tmp", command: "true"))
        store.appendOutput(jobID: jobID, stdout: OutputSessionFormatting.completionStatus(exitCode: 0))

        let job = store.jobs.first { $0.id == jobID }
        XCTAssertEqual(job?.stderr, "")
        XCTAssertNotNil(job?.stdout.range(of: "cd: no such file"))
        XCTAssertNotNil(job?.stdout.range(of: "true"))
        guard let stdout = job?.stdout,
              let errorRange = stdout.range(of: "cd: no such file"),
              let nextPromptRange = stdout.range(of: "true") else {
            return XCTFail("missing transcript")
        }
        XCTAssertLessThan(errorRange.lowerBound, nextPromptRange.lowerBound)
    }

    func testClearCommandClearsOutputWithoutShellRun() {
        let store = JobStore.shared
        store.removeAllJobs()

        let jobID = store.createJob(
            snippetName: "Test",
            displayCommand: "ls",
            source: .snippet(id: UUID(), name: "Test")
        )
        store.appendOutput(jobID: jobID, stdout: "line one\n")
        store.markRunning(jobID: jobID, process: Process())
        store.markFinished(jobID: jobID, exitCode: 1)

        store.executeInPlace(
            jobID: jobID,
            rawCommand: "clear",
            context: OutputExecutionContext(cwd: "/tmp", selectedItems: [], showHiddenFiles: false)
        )

        let job = store.jobs.first { $0.id == jobID }
        XCTAssertEqual(job?.stdout, "")
        XCTAssertEqual(job?.stderr, "")
        XCTAssertEqual(job?.status, .succeeded)
        XCTAssertEqual(job?.exitCode, 0)
    }
}
