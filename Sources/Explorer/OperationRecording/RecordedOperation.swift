import Foundation

enum PasteMode: String, Codable, Equatable {
    case copy
    case move
}

struct RecordedFilePair: Equatable {
    var source: URL
    var destination: URL
}

/// 单次已成功执行、可录制为 Snippet 的操作。
enum RecordedOperation: Equatable {
    case copy(sources: [URL])
    case cut(sources: [URL])
    case paste(pairs: [RecordedFilePair], mode: PasteMode)
    case transferItems(pairs: [RecordedFilePair], mode: PasteMode)
    case trash(urls: [URL])
    case deleteImmediately(urls: [URL])
    case rename(source: URL, destination: URL)
    case createDirectory(url: URL)
    case createFile(url: URL)
}

struct RecordedOperationStep: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let operation: RecordedOperation
    var isIncluded: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: RecordedOperation,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.isIncluded = isIncluded
    }
}
