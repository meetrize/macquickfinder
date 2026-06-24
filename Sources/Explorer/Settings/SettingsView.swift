import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var previewPrefillExtension: String?
    @State private var showPreviewRuleEditor = false

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            SnippetsSettingsTab()
                .tabItem {
                    Label("Snippets", systemImage: "terminal")
                }
                .tag(SettingsTab.snippets)

            PreviewSettingsTab(
                prefillExtension: $previewPrefillExtension,
                showEditor: $showPreviewRuleEditor
            )
            .tabItem {
                Label("预览", systemImage: "eye")
            }
            .tag(SettingsTab.preview)

            AdvancedSettingsTab()
                .tabItem {
                    Label("高级", systemImage: "slider.horizontal.3")
                }
                .tag(SettingsTab.advanced)
        }
        .frame(width: 520, height: 460)
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
                Picker("面板显示模式", selection: $settings.displayMode) {
                    ForEach(SnippetsDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Toggle("最近执行置顶", isOn: $settings.pinRecentlyExecutedSnippets)
                Stepper(value: $settings.maxConcurrentJobs, in: 1...4) {
                    Text("Job 并发上限：\(settings.maxConcurrentJobs)")
                }
                Toggle("Shell 执行时自动展开输出面板", isOn: $settings.autoShowOutputPanelOnShellRun)
                Toggle("危险命令二次确认", isOn: $settings.confirmDestructiveSnippets)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct GeneralSettingsTab: View {
    @AppStorage(AppPreferences.General.blankDoubleClickAction)
    private var blankDoubleClickAction = BlankDoubleClickAction.navigateToParent.rawValue
    @AppStorage(AppPreferences.General.windowSnapEnabled)
    private var windowSnapEnabled = true
    @StateObject private var defaultFileViewerSettings = DefaultFileViewerSettingsModel()
    
    var body: some View {
        Form {
            Section {
                Picker("空白处双击", selection: $blankDoubleClickAction) {
                    ForEach(BlankDoubleClickAction.allCases) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Toggle("启用窗口吸附与联动移动", isOn: $windowSnapEnabled)
            }

            DefaultFileViewerSettingsSection(model: defaultFileViewerSettings, style: .compact)
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            defaultFileViewerSettings.refresh()
        }
    }
}

private struct AdvancedSettingsTab: View {
    @StateObject private var defaultFileViewerSettings = DefaultFileViewerSettingsModel()

    var body: some View {
        Form {
            DefaultFileViewerSettingsSection(model: defaultFileViewerSettings, style: .detailed)
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            defaultFileViewerSettings.refresh()
        }
    }
}

private enum DefaultFileViewerSettingsSectionStyle {
    case compact
    case detailed
}

private struct DefaultFileViewerSettingsSection: View {
    @ObservedObject var model: DefaultFileViewerSettingsModel
    let style: DefaultFileViewerSettingsSectionStyle

    var body: some View {
        Section {
            LabeledContent("当前默认") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.isDefault ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(model.currentHandlerName)
                }
            }

            HStack {
                Button("设为默认文件夹查看器") {
                    model.setAsDefault()
                }
                .disabled(model.isDefault || model.isApplying)

                Button("恢复 Finder") {
                    model.restoreFinder()
                }
                .disabled(model.isFinderDefault || model.isApplying)
            }

            if model.showsRestartReminder {
                Text("更改后请注销并重新登录，或重启 Mac，才能在全部场景中生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if style == .detailed {
                Text("可将 MeoFind 设为系统默认文件夹查看器，使多数应用中的「在 Finder 中显示」等操作打开本应用。无法替代桌面图标、Dock 中的 Finder，以及系统自带的打开/保存对话框。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("默认文件夹查看器")
        }
        .alert("默认文件夹查看器", isPresented: alertBinding) {
            Button("好", role: .cancel) {
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
