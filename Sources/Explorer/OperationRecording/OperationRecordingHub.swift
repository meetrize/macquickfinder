import Foundation

@MainActor
enum OperationRecordingHub {
    private(set) static weak var activeRecorder: OperationRecorder?

    static func register(_ recorder: OperationRecorder) {
        activeRecorder = recorder
    }

    static func unregister(_ recorder: OperationRecorder) {
        guard activeRecorder?.windowID == recorder.windowID else { return }
        activeRecorder = nil
    }

    static func record(_ operation: RecordedOperation) {
        activeRecorder?.append(operation)
    }
}
