import Foundation

/// 类型安全的 UserDefaults 读写（区分「未设置」与 falsy 值）。
enum UserDefaultsStorage {
    static func bool(forKey key: String, default defaultValue: Bool, in defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    static func set(_ value: Bool, forKey key: String, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: key)
    }

    static func int(forKey key: String, default defaultValue: Int, in defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.integer(forKey: key)
    }

    static func set(_ value: Int, forKey key: String, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: key)
    }

    static func double(forKey key: String, default defaultValue: Double, in defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.double(forKey: key)
    }

    static func set(_ value: Double, forKey key: String, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: key)
    }

    static func string(forKey key: String, default defaultValue: String, in defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: key) ?? defaultValue
    }

    static func set(_ value: String, forKey key: String, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: key)
    }

    static func optionalString(forKey key: String, in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key)
    }

    static func data(forKey key: String, in defaults: UserDefaults = .standard) -> Data? {
        defaults.data(forKey: key)
    }

    static func set(_ value: Data?, forKey key: String, in defaults: UserDefaults = .standard) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

@propertyWrapper
struct UserDefaultsBool {
    private let key: String
    private let defaultValue: Bool
    private let defaults: UserDefaults

    init(wrappedValue: Bool, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.defaults = store
    }

    var wrappedValue: Bool {
        get { UserDefaultsStorage.bool(forKey: key, default: defaultValue, in: defaults) }
        set { UserDefaultsStorage.set(newValue, forKey: key, in: defaults) }
    }
}

@propertyWrapper
struct UserDefaultsInt {
    private let key: String
    private let defaultValue: Int
    private let defaults: UserDefaults

    init(wrappedValue: Int, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.defaults = store
    }

    var wrappedValue: Int {
        get { UserDefaultsStorage.int(forKey: key, default: defaultValue, in: defaults) }
        set { UserDefaultsStorage.set(newValue, forKey: key, in: defaults) }
    }
}

@propertyWrapper
struct UserDefaultsDouble {
    private let key: String
    private let defaultValue: Double
    private let defaults: UserDefaults

    init(wrappedValue: Double, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.defaults = store
    }

    var wrappedValue: Double {
        get { UserDefaultsStorage.double(forKey: key, default: defaultValue, in: defaults) }
        set { UserDefaultsStorage.set(newValue, forKey: key, in: defaults) }
    }
}

@propertyWrapper
struct UserDefaultsString {
    private let key: String
    private let defaultValue: String
    private let defaults: UserDefaults

    init(wrappedValue: String, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.defaults = store
    }

    var wrappedValue: String {
        get { UserDefaultsStorage.string(forKey: key, default: defaultValue, in: defaults) }
        set { UserDefaultsStorage.set(newValue, forKey: key, in: defaults) }
    }
}
