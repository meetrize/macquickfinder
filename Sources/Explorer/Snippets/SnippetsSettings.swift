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

    private init() {
        let d = UserDefaults.standard
        pinRecentlyExecutedSnippets = d.object(forKey: ExplorerAppSettings.pinRecentlyExecutedSnippetsKey) as? Bool ?? true
        maxConcurrentJobs = d.object(forKey: ExplorerAppSettings.maxConcurrentJobsKey) as? Int ?? 2
        autoShowOutputPanelOnShellRun = d.object(forKey: ExplorerAppSettings.autoShowOutputPanelOnShellRunKey) as? Bool ?? true
        confirmDestructiveSnippets = d.object(forKey: ExplorerAppSettings.confirmDestructiveSnippetsKey) as? Bool ?? true
    }

    var clampedMaxConcurrentJobs: Int {
        min(max(maxConcurrentJobs, 1), 4)
    }
}
