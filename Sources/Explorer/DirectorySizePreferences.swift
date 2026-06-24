import Foundation

enum DirectorySizePreferences {
    static var autoCalculateKey: String { AppPreferences.Directory.autoCalculateDirectorySizes }

    static var autoCalculateDirectorySizes: Bool {
        get {
            UserDefaultsStorage.bool(
                forKey: AppPreferences.Directory.autoCalculateDirectorySizes,
                default: true
            )
        }
        set {
            UserDefaultsStorage.set(
                newValue,
                forKey: AppPreferences.Directory.autoCalculateDirectorySizes
            )
        }
    }
}
