import Foundation

struct SnippetRecordingDraft: Equatable {
    var suggestedName: String
    var suggestedScope: SnippetScope
    var content: String
}
