import Foundation
import Combine

@MainActor
final class SnippetsSettings: ObservableObject {
    static let shared = SnippetsSettings()

    @Published var pinRecentlyExecutedSnippets: Bool {
        didSet { UserDefaults.standard.set(pinRecentlyExecutedSnippets, forKey: ExplorerAppSettings.pinRecentlyExecutedSnippetsKey) }
    }

    @Published var maxConcurrentJobs: Int {
        didSet { UserDefaults.standard.set(maxConcurrentJobs, forKey: ExplorerAppSettings.maxConcurrentJobsKey) }
    }

    @Published var autoShowOutputPanelOnShellRun: Bool {
        didSet { UserDefaults.standard.set(autoShowOutputPanelOnShellRun, forKey: ExplorerAppSettings.autoShowOutputPanelOnShellRunKey) }
    }

    @Published var confirmDestructiveSnippets: Bool {
        didSet { UserDefaults.standard.set(confirmDestructiveSnippets, forKey: ExplorerAppSettings.confirmDestructiveSnippetsKey) }
    }

    @Published var isOutputPanelVisible: Bool {
        didSet { UserDefaults.standard.set(isOutputPanelVisible, forKey: ExplorerAppSettings.outputPanelVisibleKey) }
    }

    @Published var outputPanelHeight: Double {
        didSet { UserDefaults.standard.set(outputPanelHeight, forKey: ExplorerAppSettings.outputPanelHeightKey) }
    }

    @Published var isSnippetsContentCollapsed: Bool {
        didSet { UserDefaults.standard.set(isSnippetsContentCollapsed, forKey: ExplorerAppSettings.snippetsContentCollapsedKey) }
    }

    @Published var isOutputPanelContentCollapsed: Bool {
        didSet { UserDefaults.standard.set(isOutputPanelContentCollapsed, forKey: ExplorerAppSettings.outputPanelContentCollapsedKey) }
    }

    @Published var isPreviewContentCollapsed: Bool {
        didSet { UserDefaults.standard.set(isPreviewContentCollapsed, forKey: ExplorerAppSettings.previewContentCollapsedKey) }
    }

    private init() {
        let d = UserDefaults.standard
        pinRecentlyExecutedSnippets = d.object(forKey: ExplorerAppSettings.pinRecentlyExecutedSnippetsKey) as? Bool ?? true
        maxConcurrentJobs = d.object(forKey: ExplorerAppSettings.maxConcurrentJobsKey) as? Int ?? 2
        autoShowOutputPanelOnShellRun = d.object(forKey: ExplorerAppSettings.autoShowOutputPanelOnShellRunKey) as? Bool ?? true
        confirmDestructiveSnippets = d.object(forKey: ExplorerAppSettings.confirmDestructiveSnippetsKey) as? Bool ?? true
        isOutputPanelVisible = d.object(forKey: ExplorerAppSettings.outputPanelVisibleKey) as? Bool ?? false
        outputPanelHeight = d.object(forKey: ExplorerAppSettings.outputPanelHeightKey) as? Double ?? 200
        isSnippetsContentCollapsed = d.object(forKey: ExplorerAppSettings.snippetsContentCollapsedKey) as? Bool ?? false
        isOutputPanelContentCollapsed = d.object(forKey: ExplorerAppSettings.outputPanelContentCollapsedKey) as? Bool ?? false
        isPreviewContentCollapsed = d.object(forKey: ExplorerAppSettings.previewContentCollapsedKey) as? Bool ?? false
    }

    var clampedMaxConcurrentJobs: Int {
        min(max(maxConcurrentJobs, 1), 4)
    }
}
