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
    case advanced
}

struct PreviewSettingsTab: View {
    @ObservedObject private var store = CustomPreviewRuleStore.shared
    @Binding var prefillExtension: String?
    @Binding var showEditor: Bool
    @AppStorage(ExplorerAppSettings.previewBrowserSameTypeOnlyKey)
    private var previewBrowserSameTypeOnly = false

    @State private var editingRule: CustomPreviewRule?
    @State private var showBuiltInCatalog = false
    @State private var importExportMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("独立窗口浏览条仅显示同扩展名", isOn: $previewBrowserSameTypeOnly)
            } header: {
                Text("独立窗口浏览")
            } footer: {
                Text("开启后，弹出预览窗口时胶片条与 ← → 导航仅在同类型文件间切换。")
            }

            Section {
                if store.rules.isEmpty {
                    Text("尚未添加自定义规则。选中无法预览的文件时，可直接在预览面板一键添加。")
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

                Button("添加规则…") {
                    editingRule = nil
                    showEditor = true
                }
            } header: {
                Text("自定义文件类型")
            }

            Section {
                Button("导出规则…") { exportRules() }
                    .disabled(store.rules.isEmpty)
                Button("导入规则…") { importRules() }
            }

            Section {
                DisclosureGroup("内置预览类型（只读）", isExpanded: $showBuiltInCatalog) {
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
        .alert("导入 / 导出", isPresented: Binding(
            get: { importExportMessage != nil },
            set: { if !$0 { importExportMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importExportMessage ?? "")
        }
    }

    private func exportRules() {
        let panel = NSSavePanel()
        panel.title = "导出自定义预览规则"
        panel.nameFieldStringValue = "custom-preview-rules.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportJSON().write(to: url, options: .atomic)
            importExportMessage = "已导出 \(store.rules.count) 条规则。"
        } catch {
            importExportMessage = error.localizedDescription
        }
    }

    private func importRules() {
        let panel = NSOpenPanel()
        panel.title = "导入自定义预览规则"
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
            importExportMessage = "导入完成。"
        } catch {
            importExportMessage = error.localizedDescription
        }
    }

    /// 返回 nil 表示用户取消。
    private func promptImportMergeOrReplace() -> Bool? {
        let alert = NSAlert()
        alert.messageText = "导入方式"
        alert.informativeText = "合并会保留现有规则并更新同 ID 条目；替换会清空现有规则。"
        alert.addButton(withTitle: "合并")
        alert.addButton(withTitle: "替换")
        alert.addButton(withTitle: "取消")
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
                Text(rule.normalizedExtensions.map { ".\($0)" }.joined(separator: ", "))
                    .font(.body)
                HStack(spacing: 6) {
                    Text(rule.mode.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if rule.overridesBuiltIn {
                        Text("覆盖内置")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    if !rule.enabled {
                        Text("已禁用")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button("编辑", action: onEdit)
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
            Text(rule == nil ? "添加预览规则" : "编辑预览规则")
                .font(.headline)

            Form {
                TextField("扩展名（逗号分隔）", text: $extensionsInput)
                    .textFieldStyle(.roundedBorder)

                Picker("预览方式", selection: $mode) {
                    ForEach(CustomPreviewMode.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }

                Text(mode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("覆盖内置预览", isOn: $overridesBuiltIn)
                Toggle("启用", isOn: $enabled)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { populateFields() }
    }

    private func populateFields() {
        if let rule {
            extensionsInput = rule.normalizedExtensions.joined(separator: ", ")
            mode = rule.mode
            overridesBuiltIn = rule.overridesBuiltIn
            enabled = rule.enabled
        } else if let prefillExtension, !prefillExtension.isEmpty {
            extensionsInput = prefillExtension
        }
    }

    private func save() {
        let extensions = CustomPreviewRule.parseExtensions(from: extensionsInput)
        guard !extensions.isEmpty else {
            validationMessage = "请至少填写一个有效扩展名。"
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
        return ext.isEmpty ? "（无扩展名）" : ".\(ext)"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("无法预览 \(displayExtension) 文件")
                .font(.headline)

            Text("可将此类型添加到自定义预览规则，或尝试 QuickLook。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button("以文本预览") { onAddRule(.text) }
                Button("QuickLook 预览") { onAddRule(.quickLook) }
            }

            Button("在设置中自定义…", action: onOpenSettings)
                .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
