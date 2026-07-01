import Foundation

enum PreviewOpenPreferences {
    static var doubleClickAction: PreviewDoubleClickAction {
        get {
            let raw = UserDefaultsStorage.string(
                forKey: AppPreferences.Preview.doubleClickAction,
                default: PreviewDoubleClickAction.defaultValue.rawValue
            )
            return PreviewDoubleClickAction(rawValue: raw) ?? .defaultValue
        }
        set {
            UserDefaultsStorage.set(newValue.rawValue, forKey: AppPreferences.Preview.doubleClickAction)
        }
    }

    static var externalOpenAction: PreviewExternalOpenAction {
        get {
            let raw = UserDefaultsStorage.string(
                forKey: AppPreferences.Preview.externalOpenAction,
                default: PreviewExternalOpenAction.defaultValue.rawValue
            )
            return PreviewExternalOpenAction(rawValue: raw) ?? .defaultValue
        }
        set {
            UserDefaultsStorage.set(newValue.rawValue, forKey: AppPreferences.Preview.externalOpenAction)
        }
    }

    static var archiveDoubleClickAction: PreviewArchiveDoubleClickAction {
        get {
            let raw = UserDefaultsStorage.string(
                forKey: AppPreferences.Preview.archiveDoubleClickAction,
                default: PreviewArchiveDoubleClickAction.defaultValue.rawValue
            )
            return PreviewArchiveDoubleClickAction(rawValue: raw) ?? .defaultValue
        }
        set {
            UserDefaultsStorage.set(newValue.rawValue, forKey: AppPreferences.Preview.archiveDoubleClickAction)
        }
    }

    static var externalMultiImageOpen: PreviewExternalMultiImageOpenStrategy {
        get {
            let raw = UserDefaultsStorage.string(
                forKey: AppPreferences.Preview.externalMultiImageOpen,
                default: PreviewExternalMultiImageOpenStrategy.defaultValue.rawValue
            )
            return PreviewExternalMultiImageOpenStrategy(rawValue: raw) ?? .defaultValue
        }
        set {
            UserDefaultsStorage.set(newValue.rawValue, forKey: AppPreferences.Preview.externalMultiImageOpen)
        }
    }
}
