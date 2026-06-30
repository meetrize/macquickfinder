import SwiftUI
import FileList

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var previewPrefillExtension: String?
    @State private var showPreviewRuleEditor = false

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label(L10n.Settings.Tab.general, systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            SnippetsSettingsTab()
                .tabItem {
                    Label(L10n.Settings.Tab.snippets, systemImage: "terminal")
                }
                .tag(SettingsTab.snippets)

            PreviewSettingsTab(
                prefillExtension: $previewPrefillExtension,
                showEditor: $showPreviewRuleEditor
            )
            .tabItem {
                Label(L10n.Settings.Tab.preview, systemImage: "eye")
            }
            .tag(SettingsTab.preview)

            ShortcutsSettingsTab()
                .tabItem {
                    Label(L10n.Settings.Tab.shortcuts, systemImage: "keyboard")
                }
                .tag(SettingsTab.shortcuts)

        }
        .frame(width: 520, height: 500)
        .onAppear {
            if let ext = SettingsWindowPresenter.shared.consumePendingPrefillExtension() {
                selectedTab = .preview
                previewPrefillExtension = ext
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPreviewSettingsRequested)) { notification in
            selectedTab = .preview
            if let ext = notification.userInfo?["extension"] as? String {
                previewPrefillExtension = ext
            }
        }
    }
}

private struct SnippetsSettingsTab: View {
    @ObservedObject private var settings = SnippetsSettings.shared

    var body: some View {
        Form {
            Section {
                Picker(L10n.Settings.Snippets.displayMode, selection: $settings.displayMode) {
                    ForEach(SnippetsDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Toggle(L10n.Settings.Snippets.pinRecent, isOn: $settings.pinRecentlyExecutedSnippets)
                Stepper(value: $settings.maxConcurrentJobs, in: 1...4) {
                    Text(L10n.Settings.Snippets.jobConcurrencyLimit(settings.maxConcurrentJobs))
                }
                Toggle(L10n.Settings.Snippets.autoShowOutput, isOn: $settings.autoShowOutputPanelOnShellRun)
                Toggle(L10n.Settings.Snippets.confirmDestructive, isOn: $settings.confirmDestructiveSnippets)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject private var languageSettings = InterfaceLanguageSettings.shared
    @AppStorage(AppPreferences.General.blankDoubleClickAction)
    private var blankDoubleClickAction = BlankDoubleClickAction.navigateToParent.rawValue
    @AppStorage(AppPreferences.General.windowSnapEnabled)
    private var windowSnapEnabled = true
    @AppStorage(AppPreferences.FileList.rowHoverHighlight)
    private var rowHoverHighlight = true
    @StateObject private var defaultFileViewerSettings = DefaultFileViewerSettingsModel()
    @StateObject private var defaultImageViewerSettings = DefaultImageViewerSettingsModel()
    
    var body: some View {
        Form {
            Section {
                Picker(L10n.Settings.General.interfaceLanguage, selection: $languageSettings.language) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(language.pickerLabel).tag(language)
                    }
                }
                Text(L10n.Settings.General.interfaceLanguageFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Picker(L10n.Settings.General.blankDoubleClick, selection: $blankDoubleClickAction) {
                    ForEach(BlankDoubleClickAction.allCases) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Toggle(L10n.Settings.General.windowSnap, isOn: $windowSnapEnabled)
                Toggle(L10n.Settings.General.fileListRowHover, isOn: $rowHoverHighlight)
            }

            DefaultFileViewerSettingsSection(model: defaultFileViewerSettings)
            DefaultImageViewerSettingsSection(model: defaultImageViewerSettings)
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            defaultFileViewerSettings.refresh()
            defaultImageViewerSettings.refresh()
        }
    }
}

private struct DefaultFileViewerSettingsSection: View {
    @ObservedObject var model: DefaultFileViewerSettingsModel

    var body: some View {
        Section {
            LabeledContent(L10n.Settings.DefaultViewer.current) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.isDefault ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(model.currentHandlerName)
                }
            }

            HStack {
                Button(L10n.Settings.DefaultViewer.set) {
                    model.setAsDefault()
                }
                .disabled(model.isDefault || model.isApplying)

                Button(L10n.Settings.DefaultViewer.restoreFinder) {
                    model.restoreFinder()
                }
                .disabled(model.isFinderDefault || model.isApplying)
            }

            if model.showsRestartReminder {
                Text(L10n.Settings.DefaultViewer.restartHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        } header: {
            Text(L10n.Settings.DefaultViewer.title)
        }
        .alert(L10n.Settings.DefaultViewer.title, isPresented: alertBinding) {
            Button(L10n.Action.ok, role: .cancel) {
                model.alertMessage = nil
            }
        } message: {
            if let alertMessage = model.alertMessage {
                Text(alertMessage)
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.alertMessage = nil
                }
            }
        )
    }
}

private struct DefaultImageViewerSettingsSection: View {
    @ObservedObject var model: DefaultImageViewerSettingsModel

    var body: some View {
        Section {
            LabeledContent(L10n.Settings.DefaultImageViewer.current) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.isDefault ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(model.currentHandlerName)
                }
            }

            HStack {
                Button(L10n.Settings.DefaultImageViewer.set) {
                    model.setAsDefault()
                }
                .disabled(model.isDefault || model.isApplying)

                Button(L10n.Settings.DefaultImageViewer.restorePreview) {
                    model.restorePreview()
                }
                .disabled(model.isPreviewDefault || model.isApplying)
            }

            if model.showsRestartReminder {
                Text(L10n.Settings.DefaultImageViewer.restartHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        } header: {
            Text(L10n.Settings.DefaultImageViewer.title)
        } footer: {
            Text(L10n.Settings.DefaultImageViewer.footer)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .alert(L10n.Settings.DefaultImageViewer.title, isPresented: alertBinding) {
            Button(L10n.Action.ok, role: .cancel) {
                model.alertMessage = nil
            }
        } message: {
            if let alertMessage = model.alertMessage {
                Text(alertMessage)
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.alertMessage = nil
                }
            }
        )
    }
}
