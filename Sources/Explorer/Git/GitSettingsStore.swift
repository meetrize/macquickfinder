import Combine
import Foundation

extension Notification.Name {
    static let gitSettingsDidChange = Notification.Name("gitSettingsDidChange")
    static let openGitSettingsRequested = Notification.Name("openGitSettingsRequested")
}

@MainActor
final class GitSettingsStore: ObservableObject {
    static let shared = GitSettingsStore()

    @Published private(set) var customExecutablePath: String?

    private init() {
        customExecutablePath = UserDefaultsStorage.optionalString(forKey: AppPreferences.Git.customExecutablePath)
    }

    var resolvedExecutableURL: URL {
        GitCLI.resolveExecutableURL()
    }

    var isAvailable: Bool {
        GitCLI.isAvailable
    }

    func setCustomExecutablePath(_ path: String?) {
        if let path, !path.isEmpty {
            let standardized = (path as NSString).standardizingPath
            UserDefaultsStorage.set(standardized, forKey: AppPreferences.Git.customExecutablePath)
            customExecutablePath = standardized
        } else {
            UserDefaults.standard.removeObject(forKey: AppPreferences.Git.customExecutablePath)
            customExecutablePath = nil
        }
        NotificationCenter.default.post(name: .gitSettingsDidChange, object: nil)
    }
}

@MainActor
func openGitSettings() {
    NotificationCenter.default.post(name: .openGitSettingsRequested, object: nil)
    SettingsWindowPresenter.shared.openSettingsWindow()
}
