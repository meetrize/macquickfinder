import Foundation

struct OperationRecordingReviewContext: Identifiable {
    let id = UUID()
    var steps: [RecordedOperationStep]
    let recordingCWD: String
    let recordedAt: Date
    let isInTrash: Bool
}
