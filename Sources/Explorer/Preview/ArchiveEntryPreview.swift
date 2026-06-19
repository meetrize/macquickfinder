import Foundation

struct ArchiveEntryPreview: Identifiable, Equatable {
    let path: String
    let isDirectory: Bool
    let size: Int64?

    var id: String { path }
}
