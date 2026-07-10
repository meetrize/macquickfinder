import SwiftUI

struct ShortcutsSettingsTab: View {
    @ObservedObject private var settings = ShortcutSettingsStore.shared

    var body: some View {
        ScrollView {
            Form {
                globalSection
                navigationSection
                filesSection

                ForEach(AppShortcutCategory.allCases.filter { $0 != .global && $0 != .navigation && $0 != .files }) { category in
                    let items = AppShortcutRegistry.entries(for: category)
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { entry in
                                shortcutRow(name: entry.name, shortcut: entry.shortcut)
                            }
                        } header: {
                            Text(category.title)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
    }

    private var globalSection: some View {
        Section {
            Toggle(L10n.Settings.Shortcuts.globalToggleEnabled, isOn: $settings.globalToggleEnabled)

            LabeledContent(L10n.Settings.Shortcuts.globalToggle) {
                HStack(spacing: 8) {
                    ShortcutRecorderView(binding: $settings.globalToggleBinding)
                        .disabled(!settings.globalToggleEnabled)

                    Button(L10n.Settings.Shortcuts.reset) {
                        settings.resetGlobalToggleBinding()
                    }
                    .disabled(!settings.globalToggleEnabled)
                }
            }

            Text(L10n.Settings.Shortcuts.globalToggleFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(AppShortcutCategory.global.title)
        }
    }

    private var navigationSection: some View {
        Section {
            LabeledContent(L10n.Settings.Shortcuts.newTab) {
                HStack(spacing: 8) {
                    ShortcutRecorderView(binding: $settings.newTabBinding)

                    Button(L10n.Settings.Shortcuts.reset) {
                        settings.resetNewTabBinding()
                    }
                }
            }

            ForEach(AppShortcutRegistry.entries(for: .navigation).filter { $0.id != "new_tab" }) { entry in
                shortcutRow(name: entry.name, shortcut: entry.shortcut)
            }
        } header: {
            Text(AppShortcutCategory.navigation.title)
        }
    }

    private var filesSection: some View {
        Section {
            LabeledContent(L10n.Settings.Shortcuts.copyPath) {
                HStack(spacing: 8) {
                    ShortcutRecorderView(binding: $settings.copyPathBinding)

                    Button(L10n.Settings.Shortcuts.reset) {
                        settings.resetCopyPathBinding()
                    }
                }
            }

            ForEach(AppShortcutRegistry.entries(for: .files).filter { $0.id != "copy_path" }) { entry in
                shortcutRow(name: entry.name, shortcut: entry.shortcut)
            }
        } header: {
            Text(AppShortcutCategory.files.title)
        }
    }

    private func shortcutRow(name: String, shortcut: String) -> some View {
        LabeledContent(name) {
            Text(shortcut.isEmpty ? L10n.Help.noShortcut : shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(shortcut.isEmpty ? .tertiary : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
