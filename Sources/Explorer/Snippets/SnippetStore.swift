import Foundation

private struct SnippetsPersistenceFile: Codable {
    var schemaVersion: Int
    var snippets: [Snippet]
}

@MainActor
final class SnippetStore: ObservableObject {
    static let shared = SnippetStore()

    @Published private(set) var snippets: [Snippet] = []

    private let fileManager = FileManager.default

    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Explorer", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("snippets.json")
    }

    private init() {
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: storageURL),
           let file = try? JSONDecoder().decode(SnippetsPersistenceFile.self, from: data) {
            snippets = file.snippets.sorted { $0.sortOrder < $1.sortOrder }
            return
        }
        snippets = Self.builtinSnippets()
        save()
    }

    func save() {
        let file = SnippetsPersistenceFile(schemaVersion: SnippetDefaults.schemaVersion, snippets: snippets)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    func add(_ snippet: Snippet) {
        var s = snippet
        s.sortOrder = (snippets.map(\.sortOrder).max() ?? -1) + 1
        snippets.append(s)
        save()
    }

    func update(_ snippet: Snippet) {
        guard let idx = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        var s = snippet
        s.updatedAt = Date()
        snippets[idx] = s
        save()
    }

    func delete(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    func snippet(id: UUID) -> Snippet? {
        snippets.first { $0.id == id }
    }

    func recordExecution(id: UUID) {
        guard let idx = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[idx].lastExecutedAt = Date()
        snippets[idx].executionCount += 1
        save()
    }

    func sortedVisible(
        context: SnippetVisibilityContext,
        searchQuery: String,
        pinRecentlyExecuted: Bool
    ) -> [Snippet] {
        var result = snippets
        if SnippetDefaults.hidesUnavailableSnippets {
            result = result.filter { SnippetScopeMatcher.isVisible($0, context: context) }
        }
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = result.filter { snippetMatchesSearch($0, query: searchQuery) }
        }
        if pinRecentlyExecuted {
            result.sort { a, b in
                switch (a.lastExecutedAt, b.lastExecutedAt) {
                case let (da?, db?):
                    if da != db { return da > db }
                    return a.sortOrder < b.sortOrder
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return a.sortOrder < b.sortOrder
                }
            }
        } else {
            result.sort { $0.sortOrder < $1.sortOrder }
        }
        return result
    }

    func importItems(_ items: [SnippetImportItem], strategy: SnippetImportStrategy) -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0
        for item in items {
            if let conflict = item.conflict {
                switch strategy {
                case .skip:
                    skipped += 1
                    continue
                case .overwrite:
                    if conflict == .duplicateID, let idx = snippets.firstIndex(where: { $0.id == item.snippet.id }) {
                        snippets[idx] = item.snippet
                        imported += 1
                    } else if let idx = snippets.firstIndex(where: { $0.name.lowercased() == item.snippet.name.lowercased() }) {
                        var s = item.snippet
                        s.id = snippets[idx].id
                        snippets[idx] = s
                        imported += 1
                    } else {
                        add(item.snippet)
                        imported += 1
                    }
                case .rename:
                    var s = item.snippet
                    s.id = UUID()
                    s.name = uniqueName(for: s.name)
                    add(s)
                    imported += 1
                }
            } else {
                add(item.snippet)
                imported += 1
            }
        }
        save()
        return (imported, skipped)
    }

    private func uniqueName(for base: String) -> String {
        var candidate = "\(base) (导入)"
        var counter = 2
        let names = Set(snippets.map { $0.name.lowercased() })
        while names.contains(candidate.lowercased()) {
            candidate = "\(base) (导入 \(counter))"
            counter += 1
        }
        return candidate
    }

    static func builtinSnippets() -> [Snippet] {
        let now = Date()
        return [
            Snippet(name: "列出目录", scriptType: .shell, scope: .anytime, content: "ls -la %d",
                    sortOrder: 0, createdAt: now, updatedAt: now, isBuiltin: true),
            Snippet(name: "查看属性", scriptType: .shell, scope: .singleSelection, content: "stat %p",
                    sortOrder: 1, createdAt: now, updatedAt: now, isBuiltin: true),
            Snippet(name: "在终端打开", scriptType: .shell, scope: .anytime, content: "open -a Terminal %d",
                    sortOrder: 2, createdAt: now, updatedAt: now, isBuiltin: true),
            Snippet(name: "复制路径", scriptType: .shell, scope: .singleSelection, content: "printf '%s' %p | pbcopy",
                    sortOrder: 3, createdAt: now, updatedAt: now, isBuiltin: true),
            Snippet(name: "用默认应用打开", scriptType: .shell, scope: .filesOnly, content: "open %q",
                    sortOrder: 4, createdAt: now, updatedAt: now, isBuiltin: true),
            Snippet(name: "显示 Finder 信息", scriptType: .appleScript, scope: .singleSelection,
                    content: #"tell application "Finder" to open information window of (POSIX file "%p" as alias)"#,
                    sortOrder: 5, createdAt: now, updatedAt: now, isBuiltin: true),
            Snippet(name: "打开 PDF（预览）", scriptType: .shell, scope: .fileExtensions(["pdf"]),
                    content: "open -a Preview %q", sortOrder: 6, createdAt: now, updatedAt: now, isBuiltin: true),
        ]
    }
}
