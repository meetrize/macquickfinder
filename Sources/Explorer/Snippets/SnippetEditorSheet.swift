import SwiftUI
import AppKit
import FileList
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
    @State private var useSystemTerminal: Bool
    @State private var pendingVariableInsert: String?

    let snippet: Snippet?
    let onSave: (Snippet) -> Void
    let onDelete: ((UUID) -> Void)?
    let onExport: ((Snippet) -> Void)?
    let onClose: (() -> Void)?

    init(
        snippet: Snippet?,
        draft: SnippetRecordingDraft? = nil,
        onSave: @escaping (Snippet) -> Void,
        onDelete: ((UUID) -> Void)? = nil,
        onExport: ((Snippet) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.snippet = snippet
        self.onSave = onSave
        self.onDelete = onDelete
        self.onExport = onExport
        self.onClose = onClose

        let s = snippet ?? Snippet(
            name: draft?.suggestedName ?? "",
            scriptType: .shell,
            scope: draft?.suggestedScope ?? .global,
            content: draft?.content ?? "",
            interpreter: SnippetDefaults.shellInterpreter
        )
        _name = State(initialValue: s.name)
        _scriptType = State(initialValue: s.scriptType)
        _content = State(initialValue: s.content)
        _interpreter = State(initialValue: s.interpreter ?? SnippetDefaults.shellInterpreter)
        _useCustomInterpreter = State(initialValue: s.interpreter != nil && s.interpreter != SnippetDefaults.shellInterpreter && s.interpreter != SnippetDefaults.bashInterpreter)
        _useSystemTerminal = State(initialValue: s.useSystemTerminal)

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

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !content.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            editorScrollContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Divider()
            footer
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet == nil ? L10n.Snippets.Editor.newTitle : L10n.Snippets.Editor.editTitle)
                    .font(.title2.weight(.semibold))
                Text(L10n.Snippets.Editor.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            SnippetVariableHelpButton(footer: L10n.Snippets.VariableHelp.footer)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var editorScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                editorSection {
                    VStack(alignment: .leading, spacing: 14) {
                        configurationSubsection(title: L10n.Snippets.Editor.sectionGeneral) {
                            TextField(L10n.Snippets.Editor.name, text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        configurationSubsection(title: L10n.Snippets.Editor.sectionScope) {
                            scopePicker

                            if scopeKind == .fileExtensions {
                                TextField(L10n.Snippets.Editor.extensionsPlaceholder, text: $scopeValues)
                                    .textFieldStyle(.roundedBorder)
                            }
                            if scopeKind == .specificFiles {
                                TextField(L10n.Snippets.Editor.pathsPlaceholder, text: $scopeValues, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }
                        }

                        configurationSubsection(title: L10n.Snippets.Editor.sectionExecution) {
                            scriptTypePicker

                            if scriptType == .shell {
                                Picker(L10n.Snippets.Editor.interpreter, selection: $interpreter) {
                                    Text("zsh").tag(SnippetDefaults.shellInterpreter)
                                    Text("bash").tag(SnippetDefaults.bashInterpreter)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }

                            if scriptType == .shell || scriptType == .python3 {
                                Toggle(L10n.Snippets.Editor.useSystemTerminal, isOn: $useSystemTerminal)
                                Text(L10n.Snippets.Editor.terminalHint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                editorSection(title: L10n.Snippets.Editor.sectionScript) {
                    scriptEditor
                    variableChips
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func configurationSubsection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var scopePicker: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96, maximum: 148), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(SnippetScopeKind.allCases) { kind in
                selectionChip(
                    title: kind.displayName,
                    isSelected: scopeKind == kind,
                    tooltip: kind.scopeDescription
                ) {
                    scopeKind = kind
                }
            }
        }
    }

    private var scriptTypePicker: some View {
        HStack(spacing: 8) {
            ForEach(SnippetScriptType.allCases) { type in
                selectionChip(
                    title: type.displayName,
                    isSelected: scriptType == type,
                    tooltip: nil
                ) {
                    scriptType = type
                    if type != .shell && type != .python3 {
                        useSystemTerminal = false
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func selectionChip(
        title: String,
        isSelected: Bool,
        tooltip: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.caption)
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(OptionalHoverTooltip(text: tooltip))
    }

    private var scriptEditor: some View {
        SnippetScriptTextEditor(text: $content, pendingInsert: $pendingVariableInsert)
            .frame(minHeight: 180)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
    }

    private var variableChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Snippets.Editor.insertVariable)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 52, maximum: 80), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(SnippetVariableCatalog.all) { variable in
                    Button(variable.token) {
                        pendingVariableInsert = variable.token
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(.caption, design: .monospaced))
                    .instantHoverTooltip(variable.description)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let snippet, let onDelete {
                Button(L10n.Action.delete, role: .destructive) {
                    onDelete(snippet.id)
                    close()
                }
            }
            if let snippet, let onExport {
                Button(L10n.Snippets.Panel.exportSingle) { onExport(snippet) }
            }
            Spacer()
            Button(L10n.Action.cancel) { close() }
                .keyboardShortcut(.cancelAction)
            Button(L10n.Action.save) { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
        .padding(20)
        .background {
            Button("", action: save)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!canSave)
                .hidden()
        }
    }

    @ViewBuilder
    private func editorSection<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
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
        s.useSystemTerminal = (scriptType == .shell || scriptType == .python3) && useSystemTerminal
        s.updatedAt = Date()
        onSave(s)
        close()
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

private struct OptionalHoverTooltip: ViewModifier {
    let text: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let text, !text.isEmpty {
            content.instantHoverTooltip(text)
        } else {
            content
        }
    }
}
