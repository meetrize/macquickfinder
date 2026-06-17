import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SnippetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var scriptType: SnippetScriptType
    @State private var scopeKind: SnippetScopeKind
    @State private var scopeValues: String
    @State private var content: String
    @State private var interpreter: String
    @State private var useCustomInterpreter: Bool

    let snippet: Snippet?
    let onSave: (Snippet) -> Void
    let onDelete: ((UUID) -> Void)?
    let onExport: ((Snippet) -> Void)?

    init(
        snippet: Snippet?,
        onSave: @escaping (Snippet) -> Void,
        onDelete: ((UUID) -> Void)? = nil,
        onExport: ((Snippet) -> Void)? = nil
    ) {
        self.snippet = snippet
        self.onSave = onSave
        self.onDelete = onDelete
        self.onExport = onExport

        let s = snippet ?? Snippet(
            name: "",
            scriptType: .shell,
            scope: .global,
            content: "",
            interpreter: SnippetDefaults.shellInterpreter
        )
        _name = State(initialValue: s.name)
        _scriptType = State(initialValue: s.scriptType)
        _content = State(initialValue: s.content)
        _interpreter = State(initialValue: s.interpreter ?? SnippetDefaults.shellInterpreter)
        _useCustomInterpreter = State(initialValue: s.interpreter != nil && s.interpreter != SnippetDefaults.shellInterpreter && s.interpreter != SnippetDefaults.bashInterpreter)

        switch s.scope {
        case .fileExtensions(let exts):
            _scopeKind = State(initialValue: .fileExtensions)
            _scopeValues = State(initialValue: exts.joined(separator: ", "))
        case .specificFiles(let paths):
            _scopeKind = State(initialValue: .specificFiles)
            _scopeValues = State(initialValue: paths.joined(separator: "\n"))
        default:
            _scopeKind = State(initialValue: s.scope.kind)
            _scopeValues = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snippet == nil ? "新建 Snippet" : "编辑 Snippet")
                .font(.headline)

            TextField("名称", text: $name)

            Picker("作用域", selection: $scopeKind) {
                ForEach(SnippetScopeKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            if scopeKind == .fileExtensions {
                TextField("扩展名（逗号分隔，如 pdf, md）", text: $scopeValues)
            }
            if scopeKind == .specificFiles {
                TextField("文件路径（每行一个）", text: $scopeValues, axis: .vertical)
                    .lineLimit(3...6)
            }

            Picker("脚本类型", selection: $scriptType) {
                ForEach(SnippetScriptType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            if scriptType == .shell {
                Picker("解释器", selection: $interpreter) {
                    Text("zsh").tag(SnippetDefaults.shellInterpreter)
                    Text("bash").tag(SnippetDefaults.bashInterpreter)
                }
            }

            Text("内容")
                .font(.subheadline)
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)

            variableChips

            HStack {
                if let snippet, let onDelete {
                    Button("删除", role: .destructive) {
                        onDelete(snippet.id)
                        dismiss()
                    }
                }
                if let snippet, let onExport {
                    Button("导出此条") { onExport(snippet) }
                }
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var variableChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(["%p", "%d", "%P", "%f", "%q"], id: \.self) { ph in
                    Button(ph) { content += ph }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    private func save() {
        let scope = buildScope()
        var s = snippet ?? Snippet(name: name, scriptType: scriptType, scope: scope, content: content)
        s.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        s.scriptType = scriptType
        s.scope = scope
        s.content = content
        s.interpreter = scriptType == .shell ? interpreter : nil
        s.updatedAt = Date()
        onSave(s)
        dismiss()
    }

    private func buildScope() -> SnippetScope {
        switch scopeKind {
        case .anytime: return .anytime
        case .global: return .global
        case .filesOnly: return .filesOnly
        case .directoriesOnly: return .directoriesOnly
        case .singleSelection: return .singleSelection
        case .fileExtensions:
            let exts = scopeValues.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
            return .fileExtensions(exts)
        case .specificFiles:
            let paths = scopeValues.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return .specificFiles(paths)
        }
    }
}
