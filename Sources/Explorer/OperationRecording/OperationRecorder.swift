import Foundation

@MainActor
final class OperationRecorder: ObservableObject {
    let windowID: UUID

    @Published private(set) var isRecording = false
    @Published private(set) var steps: [RecordedOperationStep] = []

    private(set) var recordingStartCWD: String?

    init(windowID: UUID = UUID()) {
        self.windowID = windowID
    }

    var stepCount: Int { steps.count }

    func start(cwd: String) {
        steps.removeAll()
        recordingStartCWD = cwd
        isRecording = true
    }

    @discardableResult
    func stop() -> [RecordedOperationStep] {
        isRecording = false
        recordingStartCWD = nil
        return steps
    }

    func discard() {
        steps.removeAll()
        isRecording = false
        recordingStartCWD = nil
    }

    func append(_ operation: RecordedOperation) {
        guard isRecording else { return }
        steps.append(RecordedOperationStep(operation: operation))
    }
}
