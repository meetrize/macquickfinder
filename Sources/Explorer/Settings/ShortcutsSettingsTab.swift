import SwiftUI

struct ShortcutsSettingsTab: View {
    @ObservedObject private var settings = ShortcutSettingsStore.shared

    var body: some View {
        ScrollView {
            Form {
                globalSection

                ForEach(AppShortcutCategory.allCases.filter { $0 != .global }) { category in
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

    private func shortcutRow(name: String, shortcut: String) -> some View {
        LabeledContent(name) {
            Text(shortcut.isEmpty ? L10n.Help.noShortcut : shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(shortcut.isEmpty ? .tertiary : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
