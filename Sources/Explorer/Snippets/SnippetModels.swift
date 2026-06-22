import Foundation

enum SnippetScriptType: String, Codable, CaseIterable, Identifiable {
    case shell
    case python3
    case appleScript

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shell: return "Shell"
        case .python3: return "Python 3"
        case .appleScript: return "AppleScript"
        }
    }
}

enum SnippetScopeKind: String, Codable, CaseIterable, Identifiable {
    case anytime
    case global
    case filesOnly
    case directoriesOnly
    case singleSelection
    case fileExtensions
    case specificFiles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anytime: return "始终"
        case .global: return "有选中项"
        case .filesOnly: return "仅文件"
        case .directoriesOnly: return "仅目录"
        case .singleSelection: return "单选"
        case .fileExtensions: return "指定扩展名"
        case .specificFiles: return "指定文件"
        }
    }
}

enum SnippetScope: Codable, Equatable, Hashable {
    case anytime
    case global
    case filesOnly
    case directoriesOnly
    case singleSelection
    case fileExtensions([String])
    case specificFiles([String])

    var kind: SnippetScopeKind {
        switch self {
        case .anytime: return .anytime
        case .global: return .global
        case .filesOnly: return .filesOnly
        case .directoriesOnly: return .directoriesOnly
        case .singleSelection: return .singleSelection
        case .fileExtensions: return .fileExtensions
        case .specificFiles: return .specificFiles
        }
    }

    var shortBadge: String? {
        switch self {
        case .anytime, .global: return nil
        case .filesOnly: return "文件"
        case .directoriesOnly: return "目录"
        case .singleSelection: return "1项"
        case .fileExtensions(let exts): return exts.first.map { $0.lowercased() }
        case .specificFiles: return "路径"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(SnippetScopeKind.self, forKey: .kind)
        let values = try container.decodeIfPresent([String].self, forKey: .values) ?? []
        switch kind {
        case .anytime: self = .anytime
        case .global: self = .global
        case .filesOnly: self = .filesOnly
        case .directoriesOnly: self = .directoriesOnly
        case .singleSelection: self = .singleSelection
        case .fileExtensions: self = .fileExtensions(values)
        case .specificFiles: self = .specificFiles(values)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .fileExtensions(let exts):
            try container.encode(exts, forKey: .values)
        case .specificFiles(let paths):
            try container.encode(paths, forKey: .values)
        default:
            break
        }
    }
}

enum SnippetWorkingDirectory: Codable, Equatable, Hashable {
    case cwd
    case selectedParent
    case fixedPath(String)
}

struct SnippetVariableHint: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var placeholder: String
    var label: String
    var example: String?

    init(id: UUID = UUID(), placeholder: String, label: String, example: String? = nil) {
        self.id = id
        self.placeholder = placeholder
        self.label = label
        self.example = example
    }
}

struct Snippet: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var scriptType: SnippetScriptType
    var scope: SnippetScope
    var content: String
    var variableHints: [SnippetVariableHint]
    var sortOrder: Int
    var lastExecutedAt: Date?
    var executionCount: Int
    var createdAt: Date
    var updatedAt: Date
    var isBuiltin: Bool
    var workingDirectory: SnippetWorkingDirectory?
    var interpreter: String?
    /// 为 true 时默认在系统终端（Terminal 等）中执行，而非应用内输出面板。
    var useSystemTerminal: Bool

    init(
        id: UUID = UUID(),
        name: String,
        scriptType: SnippetScriptType,
        scope: SnippetScope,
        content: String,
        variableHints: [SnippetVariableHint] = [],
        sortOrder: Int = 0,
        lastExecutedAt: Date? = nil,
        executionCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isBuiltin: Bool = false,
        workingDirectory: SnippetWorkingDirectory? = nil,
        interpreter: String? = nil,
        useSystemTerminal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.scriptType = scriptType
        self.scope = scope
        self.content = content
        self.variableHints = variableHints
        self.sortOrder = sortOrder
        self.lastExecutedAt = lastExecutedAt
        self.executionCount = executionCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isBuiltin = isBuiltin
        self.workingDirectory = workingDirectory
        self.interpreter = interpreter
        self.useSystemTerminal = useSystemTerminal
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, scriptType, scope, content, variableHints, sortOrder
        case lastExecutedAt, executionCount, createdAt, updatedAt, isBuiltin
        case workingDirectory, interpreter, useSystemTerminal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        scriptType = try c.decode(SnippetScriptType.self, forKey: .scriptType)
        scope = try c.decode(SnippetScope.self, forKey: .scope)
        content = try c.decode(String.self, forKey: .content)
        variableHints = try c.decodeIfPresent([SnippetVariableHint].self, forKey: .variableHints) ?? []
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        lastExecutedAt = try c.decodeIfPresent(Date.self, forKey: .lastExecutedAt)
        executionCount = try c.decodeIfPresent(Int.self, forKey: .executionCount) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        isBuiltin = try c.decodeIfPresent(Bool.self, forKey: .isBuiltin) ?? false
        workingDirectory = try c.decodeIfPresent(SnippetWorkingDirectory.self, forKey: .workingDirectory)
        interpreter = try c.decodeIfPresent(String.self, forKey: .interpreter)
        useSystemTerminal = try c.decodeIfPresent(Bool.self, forKey: .useSystemTerminal) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(scriptType, forKey: .scriptType)
        try c.encode(scope, forKey: .scope)
        try c.encode(content, forKey: .content)
        try c.encode(variableHints, forKey: .variableHints)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encodeIfPresent(lastExecutedAt, forKey: .lastExecutedAt)
        try c.encode(executionCount, forKey: .executionCount)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(isBuiltin, forKey: .isBuiltin)
        try c.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
        try c.encodeIfPresent(interpreter, forKey: .interpreter)
        try c.encode(useSystemTerminal, forKey: .useSystemTerminal)
    }
}

struct SnippetVisibilityContext: Equatable {
    var cwd: String
    var selectedItems: [FileItem]
    var showHiddenFiles: Bool
}

struct SnippetExecutionContext: Equatable {
    var cwd: String
    var selectedItems: [FileItem]
    var environment: [String: String]

    init(cwd: String, selectedItems: [FileItem], environment: [String: String] = [:]) {
        self.cwd = cwd
        self.selectedItems = selectedItems
        self.environment = environment
    }
}

struct SnippetsFileEnvelope: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var app: String
    var kind: String
    var snippets: [Snippet]
}

enum SnippetImportConflict: Equatable {
    case duplicateID
    case duplicateName
}

struct SnippetImportItem: Equatable {
    var snippet: Snippet
    var conflict: SnippetImportConflict?
}

enum SnippetImportStrategy: String, CaseIterable, Identifiable {
    case skip
    case overwrite
    case rename

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skip: return "跳过"
        case .overwrite: return "覆盖"
        case .rename: return "重命名"
        }
    }
}

func snippetColumnCount(for panelWidth: CGFloat, maxColumns: Int = 4) -> Int {
    guard panelWidth > 400 else { return 1 }
    let extra = Int((panelWidth - 400) / 200)
    return min(maxColumns, 2 + extra)
}

func snippetMatchesSearch(_ snippet: Snippet, query: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return true }
    return snippet.name.lowercased().contains(q)
        || snippet.content.lowercased().contains(q)
}

func snippetContentPreview(_ content: String, limit: Int = 10) -> String {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > limit else { return trimmed }
    return String(trimmed.prefix(limit)) + "…"
}
