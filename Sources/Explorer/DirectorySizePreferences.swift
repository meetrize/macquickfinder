import Foundation

enum DirectorySizePreferences {
    static let autoCalculateKey = "autoCalculateDirectorySizes"
    
    static var autoCalculateDirectorySizes: Bool {
        get {
            guard UserDefaults.standard.object(forKey: autoCalculateKey) != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: autoCalculateKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoCalculateKey)
        }
    }
}
