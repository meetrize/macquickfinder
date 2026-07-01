import Foundation

enum SnippetImportExport {
    static func exportAll(_ snippets: [Snippet], to url: URL) throws {
        let envelope = SnippetsFileEnvelope(
            schemaVersion: SnippetDefaults.schemaVersion,
            exportedAt: Date(),
            app: "MeoFind",
            kind: "snippet-bundle",
            snippets: snippets.map { exportableCopy($0) }
        )
        let data = try JSONEncoder().encode(envelope)
        try data.write(to: url, options: .atomic)
    }

    static func exportSingle(_ snippet: Snippet, to url: URL) throws {
        let envelope = SnippetsFileEnvelope(
            schemaVersion: SnippetDefaults.schemaVersion,
            exportedAt: Date(),
            app: "MeoFind",
            kind: "snippet-single",
            snippets: [exportableCopy(snippet)]
        )
        let data = try JSONEncoder().encode(envelope)
        try data.write(to: url, options: .atomic)
    }

    static func parseImportItems(from url: URL, existing: [Snippet]) throws -> [SnippetImportItem] {
        let data = try Data(contentsOf: url)
        let decoder = makeImportDecoder()
        let snippets: [Snippet]
        if let envelope = try? decoder.decode(SnippetsFileEnvelope.self, from: data) {
            guard envelope.schemaVersion <= SnippetDefaults.schemaVersion else {
                throw SnippetImportError.unsupportedSchema
            }
            snippets = envelope.snippets
        } else if let single = try? decoder.decode(Snippet.self, from: data) {
            snippets = [single]
        } else {
            throw SnippetImportError.invalidFormat
        }
        guard snippets.count <= SnippetDefaults.maxImportCount else {
            throw SnippetImportError.tooManyItems
        }
        try validate(snippets)
        let existingIDs = Set(existing.map(\.id))
        let existingNames = Set(existing.map { $0.name.lowercased() })
        return snippets.map { snippet in
            var s = snippet
            s.isBuiltin = false
            var conflict: SnippetImportConflict?
            if existingIDs.contains(s.id) {
                conflict = .duplicateID
            } else if existingNames.contains(s.name.lowercased()) {
                conflict = .duplicateName
            }
            return SnippetImportItem(snippet: s, conflict: conflict)
        }
    }

    private static func validate(_ snippets: [Snippet]) throws {
        for snippet in snippets {
            guard !snippet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SnippetImportError.invalidSnippet(L10n.Error.SnippetImport.emptyName)
            }
            guard !snippet.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SnippetImportError.invalidSnippet(L10n.Error.SnippetImport.emptyContent)
            }
        }
    }

    private static func exportableCopy(_ snippet: Snippet) -> Snippet {
        var s = snippet
        s.lastExecutedAt = nil
        s.executionCount = 0
        return s
    }

    /// 导入时兼容 Swift 默认数值时间戳、Unix 秒与 ISO8601 字符串（设计文档示例格式）。
    private static func makeImportDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let ts = try? container.decode(Double.self) {
                if ts > 1_000_000_000 {
                    return Date(timeIntervalSince1970: ts)
                }
                return Date(timeIntervalSinceReferenceDate: ts)
            }
            if let string = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: string) { return date }
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: string) { return date }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognized date string: \(string)"
                )
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected date as number or ISO8601 string"
            )
        }
        return decoder
    }
}

enum SnippetImportError: LocalizedError {
    case invalidFormat
    case unsupportedSchema
    case tooManyItems
    case invalidSnippet(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return L10n.Error.SnippetImport.invalidFormat
        case .unsupportedSchema: return L10n.Error.SnippetImport.unsupportedSchema
        case .tooManyItems: return L10n.Error.SnippetImport.tooMany
        case .invalidSnippet(let msg): return L10n.Error.SnippetImport.invalid(msg)
        }
    }
}
