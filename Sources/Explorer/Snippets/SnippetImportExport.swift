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
        let decoder = JSONDecoder()
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
                throw SnippetImportError.invalidSnippet("名称为空")
            }
            guard !snippet.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SnippetImportError.invalidSnippet("内容为空")
            }
        }
    }

    private static func exportableCopy(_ snippet: Snippet) -> Snippet {
        var s = snippet
        s.lastExecutedAt = nil
        s.executionCount = 0
        return s
    }
}

enum SnippetImportError: LocalizedError {
    case invalidFormat
    case unsupportedSchema
    case tooManyItems
    case invalidSnippet(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "无法识别的 Snippets 文件格式"
        case .unsupportedSchema: return "不支持的文件版本"
        case .tooManyItems: return "导入条目过多"
        case .invalidSnippet(let msg): return "无效 Snippet：\(msg)"
        }
    }
}
