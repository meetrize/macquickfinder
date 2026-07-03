import Foundation

struct GitCommitEntry: Equatable, Identifiable, Sendable {
    var id: String { fullHash }
    let fullHash: String
    let shortHash: String
    let subject: String
    let relativeDate: String
}
