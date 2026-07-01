import XCTest
@testable import Explorer

@MainActor
final class OperationRecorderTests: XCTestCase {
    override func tearDown() {
        if let active = OperationRecordingHub.activeRecorder {
            OperationRecordingHub.unregister(active)
        }
        super.tearDown()
    }

    func testAppendOnlyWhileRecording() {
        let recorder = OperationRecorder()
        let url = URL(fileURLWithPath: "/tmp/example.txt")

        recorder.append(.createFile(url: url))
        XCTAssertTrue(recorder.steps.isEmpty)

        recorder.start(cwd: "/tmp")
        recorder.append(.createFile(url: url))
        XCTAssertEqual(recorder.steps.count, 1)

        recorder.stop()
        recorder.append(.createFile(url: url))
        XCTAssertEqual(recorder.steps.count, 1)
    }

    func testStopReturnsStepsAndClearsRecordingFlag() {
        let recorder = OperationRecorder()
        recorder.start(cwd: "/tmp")
        recorder.append(.createDirectory(url: URL(fileURLWithPath: "/tmp/folder")))

        let steps = recorder.stop()
        XCTAssertEqual(steps.count, 1)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.recordingStartCWD)
    }

    func testDiscardClearsSteps() {
        let recorder = OperationRecorder()
        recorder.start(cwd: "/tmp")
        recorder.append(.createDirectory(url: URL(fileURLWithPath: "/tmp/folder")))
        recorder.discard()

        XCTAssertTrue(recorder.steps.isEmpty)
        XCTAssertFalse(recorder.isRecording)
    }

    func testHubRecordsThroughActiveRecorder() {
        let recorder = OperationRecorder()
        recorder.start(cwd: "/tmp")
        OperationRecordingHub.register(recorder)

        OperationRecordingHub.record(.createFile(url: URL(fileURLWithPath: "/tmp/a.txt")))
        XCTAssertEqual(recorder.steps.count, 1)

        OperationRecordingHub.unregister(recorder)
        OperationRecordingHub.record(.createFile(url: URL(fileURLWithPath: "/tmp/b.txt")))
        XCTAssertEqual(recorder.steps.count, 1)
    }
}
