import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let openPreviewSettingsRequested = Notification.Name("openPreviewSettingsRequested")
}

enum SettingsTab: Hashable {
    case general
    case snippets
    case preview
    case shortcuts
}

struct PreviewSettingsTab: View {
    @ObservedObject private var store = CustomPreviewRuleStore.shared
    @Binding var prefillExtension: String?
    @Binding var showEditor: Bool
    @AppStorage(AppPreferences.Preview.browserSameTypeOnly)
    private var previewBrowserSameTypeOnly = false
    @AppStorage(AppPreferences.Preview.codeShowLineNumbers)
    private var codePreviewShowLineNumbers = false

    @State private var editingRule: CustomPreviewRule?
    @State private var showBuiltInCatalog = false
    @State private var importExportMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(L10n.Settings.Preview.detachedBrowseToggle, isOn: $previewBrowserSameTypeOnly)
            } header: {
                Text(L10n.Settings.Preview.detachedBrowse)
            } footer: {
                Text(L10n.Settings.Preview.detachedBrowseFooter)
            }

            Section {
                Toggle(L10n.Settings.Preview.codeLineNumbersToggle, isOn: $codePreviewShowLineNumbers)
            } header: {
                Text(L10n.Settings.Preview.codeLineNumbers)
            } footer: {
                Text(L10n.Settings.Preview.codeLineNumbersFooter)
            }

            Section {
                if store.rules.isEmpty {
                    Text(L10n.Settings.Preview.noRulesHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.rules) { rule in
                        CustomPreviewRuleRow(rule: rule) {
                            editingRule = rule
                            showEditor = true
                        } onDelete: {
                            store.deleteRule(id: rule.id)
                        }
                    }
                }

                Button(L10n.Settings.Preview.addRule) {
                    editingRule = nil
                    showEditor = true
                }
            } header: {
                Text(L10n.Settings.Preview.customTypes)
            }

            Section {
                Button(L10n.Settings.Preview.exportRules) { exportRules() }
                    .disabled(store.rules.isEmpty)
                Button(L10n.Settings.Preview.importRules) { importRules() }
            }

            Section {
                DisclosureGroup(L10n.Settings.Preview.builtinCatalog, isExpanded: $showBuiltInCatalog) {
                    ForEach(BuiltinPreviewExtensions.catalogByMode, id: \.mode) { entry in
                        LabeledContent(entry.mode) {
                            Text(entry.extensions.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showEditor, onDismiss: { prefillExtension = nil }) {
            CustomPreviewRuleEditorSheet(
                rule: editingRule,
                prefillExtension: prefillExtension
            ) { saved in
                if let existing = editingRule {
                    var updated = saved
                    updated.id = existing.id
                    store.updateRule(updated)
                } else {
                    store.addRule(saved)
                }
                showEditor = false
            } onCancel: {
                showEditor = false
            }
        }
        .onChange(of: prefillExtension) { ext in
            guard let ext, !ext.isEmpty else { return }
            editingRule = nil
            showEditor = true
        }
        .alert(L10n.Settings.Preview.importExportTitle, isPresented: Binding(
            get: { importExportMessage != nil },
            set: { if !$0 { importExportMessage = nil } }
        )) {
            Button(L10n.Action.ok, role: .cancel) {}
        } message: {
            Text(importExportMessage ?? "")
        }
        .onAppear {
            store.loadIfNeeded()
        }
    }

    private func exportRules() {
        let panel = NSSavePanel()
        panel.title = L10n.Settings.Preview.exportPanelTitle
        panel.nameFieldStringValue = "custom-preview-rules.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportJSON().write(to: url, options: .atomic)
            importExportMessage = L10n.Settings.Preview.exportSuccess(store.rules.count)
        } catch {
            importExportMessage = error.localizedDescription
        }
    }

    private func importRules() {
        let panel = NSOpenPanel()
        panel.title = L10n.Settings.Preview.importPanelTitle
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let merge: Bool
            if store.rules.isEmpty {
                merge = true
            } else if let choice = promptImportMergeOrReplace() {
                merge = choice
            } else {
                return
            }
            try store.importJSON(data, merge: merge)
            importExportMessage = L10n.Settings.Preview.importComplete
        } catch {
            importExportMessage = error.localizedDescription
        }
    }

    /// 返回 nil 表示用户取消。
    private func promptImportMergeOrReplace() -> Bool? {
        let alert = NSAlert()
        alert.messageText = L10n.Settings.Preview.importMethodTitle
        alert.informativeText = L10n.Settings.Preview.importMethodMessage
        alert.addButton(withTitle: L10n.Settings.Preview.importMerge)
        alert.addButton(withTitle: L10n.Settings.Preview.importReplace)
        alert.addButton(withTitle: L10n.Action.cancel)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn { return true }
        if response == .alertSecondButtonReturn { return false }
        return nil
    }
}

private struct CustomPreviewRuleRow: View {
    let rule: CustomPreviewRule
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.normalizedExtensions.map { CustomPreviewRule.displayLabel(forExtension: $0) }.joined(separator: ", "))
                    .font(.body)
                HStack(spacing: 6) {
                    Text(rule.mode.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if rule.overridesBuiltIn {
                        Text(L10n.Settings.Preview.overrideBuiltin)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    if !rule.enabled {
                        Text(L10n.Settings.Preview.disabled)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button(L10n.Action.edit, action: onEdit)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}

struct CustomPreviewRuleEditorSheet: View {
    let rule: CustomPreviewRule?
    let prefillExtension: String?
    let onSave: (CustomPreviewRule) -> Void
    let onCancel: () -> Void

    @State private var extensionsInput: String = ""
    @State private var mode: CustomPreviewMode = .text
    @State private var overridesBuiltIn = false
    @State private var enabled = true
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(rule == nil ? L10n.Settings.Preview.addRuleTitle : L10n.Settings.Preview.editRuleTitle)
                .font(.headline)

            Form {
                TextField(L10n.Settings.Preview.extensionsField, text: $extensionsInput)
                    .textFieldStyle(.roundedBorder)

                Picker(L10n.Settings.Preview.previewMode, selection: $mode) {
                    ForEach(CustomPreviewMode.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }

                Text(mode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.Settings.Preview.overrideBuiltinToggle, isOn: $overridesBuiltIn)
                Toggle(L10n.Settings.Preview.enabledToggle, isOn: $enabled)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(L10n.Action.cancel, action: onCancel)
                Button(L10n.Action.save) { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { populateFields() }
    }

    private func populateFields() {
        if let rule {
            extensionsInput = rule.normalizedExtensions.map { ext in
                ext == CustomPreviewRule.extensionlessKey ? L10n.Settings.Preview.extensionlessLabel : ext
            }.joined(separator: ", ")
            mode = rule.mode
            overridesBuiltIn = rule.overridesBuiltIn
            enabled = rule.enabled
        } else if let prefillExtension {
            extensionsInput = prefillExtension.isEmpty ? L10n.Settings.Preview.extensionlessLabel : prefillExtension
        }
    }

    private func save() {
        let extensions = CustomPreviewRule.parseExtensions(from: extensionsInput)
        guard !extensions.isEmpty else {
            validationMessage = L10n.Settings.Preview.validationExtensions
            return
        }
        validationMessage = nil
        onSave(
            CustomPreviewRule(
                id: rule?.id ?? UUID(),
                extensions: extensions,
                mode: mode,
                overridesBuiltIn: overridesBuiltIn,
                enabled: enabled
            )
        )
    }
}

struct CustomPreviewUnavailableView: View {
    let fileExtension: String
    let onAddRule: (CustomPreviewMode) -> Void
    let onOpenSettings: () -> Void

    private var displayExtension: String {
        let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return ext.isEmpty ? L10n.Settings.Preview.extensionlessLabel : ".\(ext)"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(L10n.Settings.Preview.unavailableTitle(displayExtension))
                .font(.headline)

            Text(L10n.Settings.Preview.unavailableHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                PreviewModeMenuButton(onSelect: onAddRule)

                Button(L10n.Settings.Preview.customize, action: onOpenSettings)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 原生 `NSPopUpButton`（pull-down）：标题在左、系统分隔与箭头在右，样式与「自定义」一致。
private struct PreviewModeMenuButton: View {
    let onSelect: (CustomPreviewMode) -> Void

    var body: some View {
        PreviewModePopUpButtonRepresentable(onSelect: onSelect)
            .fixedSize()
    }
}

private struct PreviewModePopUpButtonRepresentable: NSViewRepresentable {
    let onSelect: (CustomPreviewMode) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        popup.bezelStyle = .rounded
        popup.controlSize = .regular
        popup.autoenablesItems = true
        context.coordinator.attach(popup)
        context.coordinator.rebuildMenu()
        return popup
    }

    func updateNSView(_ popup: NSPopUpButton, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.rebuildMenu()
    }

    final class Coordinator: NSObject {
        var onSelect: (CustomPreviewMode) -> Void
        private weak var popup: NSPopUpButton?

        init(onSelect: @escaping (CustomPreviewMode) -> Void) {
            self.onSelect = onSelect
        }

        func attach(_ popup: NSPopUpButton) {
            self.popup = popup
        }

        func rebuildMenu() {
            guard let popup else { return }
            popup.removeAllItems()
            popup.addItem(withTitle: L10n.Settings.Preview.previewMode)
            for mode in CustomPreviewMode.allCases {
                let item = NSMenuItem(
                    title: mode.displayName,
                    action: #selector(Coordinator.modeSelected(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = mode.rawValue
                popup.menu?.addItem(item)
            }
            popup.selectItem(at: 0)
        }

        @objc func modeSelected(_ sender: NSMenuItem) {
            guard let raw = sender.representedObject as? String,
                  let mode = CustomPreviewMode(rawValue: raw) else { return }
            onSelect(mode)
            popup?.selectItem(at: 0)
        }
    }
}
