import Foundation
import Combine

@MainActor
final class SnippetsSettings: ObservableObject {
    static let shared = SnippetsSettings()

    @Published var pinRecentlyExecutedSnippets: Bool {
        didSet {
            UserDefaultsStorage.set(
                pinRecentlyExecutedSnippets,
                forKey: AppPreferences.Snippets.pinRecentlyExecuted
            )
        }
    }

    @Published var maxConcurrentJobs: Int {
        didSet {
            UserDefaultsStorage.set(
                maxConcurrentJobs,
                forKey: AppPreferences.Snippets.maxConcurrentJobs
            )
        }
    }

    @Published var autoShowOutputPanelOnShellRun: Bool {
        didSet {
            UserDefaultsStorage.set(
                autoShowOutputPanelOnShellRun,
                forKey: AppPreferences.Snippets.autoShowOutputPanelOnShellRun
            )
        }
    }

    @Published var confirmDestructiveSnippets: Bool {
        didSet {
            UserDefaultsStorage.set(
                confirmDestructiveSnippets,
                forKey: AppPreferences.Snippets.confirmDestructive
            )
        }
    }

    @Published var displayMode: SnippetsDisplayMode {
        didSet {
            UserDefaultsStorage.set(
                displayMode.rawValue,
                forKey: AppPreferences.Snippets.displayMode
            )
        }
    }

    private init() {
        pinRecentlyExecutedSnippets = UserDefaultsStorage.bool(
            forKey: AppPreferences.Snippets.pinRecentlyExecuted,
            default: true
        )
        maxConcurrentJobs = UserDefaultsStorage.int(
            forKey: AppPreferences.Snippets.maxConcurrentJobs,
            default: 2
        )
        autoShowOutputPanelOnShellRun = UserDefaultsStorage.bool(
            forKey: AppPreferences.Snippets.autoShowOutputPanelOnShellRun,
            default: true
        )
        confirmDestructiveSnippets = UserDefaultsStorage.bool(
            forKey: AppPreferences.Snippets.confirmDestructive,
            default: true
        )
        if let raw = UserDefaults.standard.string(forKey: AppPreferences.Snippets.displayMode),
           let mode = SnippetsDisplayMode(rawValue: raw) {
            displayMode = mode
        } else {
            displayMode = .standard
        }
    }

    var clampedMaxConcurrentJobs: Int {
        min(max(maxConcurrentJobs, 1), 4)
    }
}
