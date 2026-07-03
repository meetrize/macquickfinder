import Foundation

enum GitLogParser {
    static let defaultLimit = 12
    private static let fieldSeparator: Character = "\u{1F}"

    static func parse(zTerminated data: Data, limit: Int = defaultLimit) -> [GitCommitEntry] {
        guard !data.isEmpty else { return [] }

        var entries: [GitCommitEntry] = []
        var index = data.startIndex

        while index < data.endIndex, entries.count < limit {
            guard let recordEnd = data[index...].firstIndex(of: 0) else { break }
            let recordData = data[index..<recordEnd]
            index = data.index(after: recordEnd)

            guard let record = String(data: recordData, encoding: .utf8) else { continue }
            let fields = record.split(separator: fieldSeparator, omittingEmptySubsequences: false)
            guard fields.count >= 4 else { continue }

            let fullHash = String(fields[0])
            let shortHash = String(fields[1])
            let subject = String(fields[2])
            let relativeDate = String(fields[3])
            guard !fullHash.isEmpty, !subject.isEmpty else { continue }

            entries.append(
                GitCommitEntry(
                    fullHash: fullHash,
                    shortHash: shortHash.isEmpty ? String(fullHash.prefix(7)) : shortHash,
                    subject: subject,
                    relativeDate: relativeDate
                )
            )
        }

        return entries
    }
}
