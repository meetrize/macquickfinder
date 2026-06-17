import Foundation

enum JobStatus: String, Codable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled
}

enum JobSource: Equatable {
    case snippet(id: UUID, name: String)
}

struct JobRecord: Identifiable {
    let id: UUID
    var snippetName: String
    var displayCommand: String
    var source: JobSource
    var status: JobStatus
    var stdout: String
    var stderr: String
    var exitCode: Int32?
    var startedAt: Date?
    var endedAt: Date?
    var process: Process?

    var duration: TimeInterval? {
        guard let startedAt, let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}
