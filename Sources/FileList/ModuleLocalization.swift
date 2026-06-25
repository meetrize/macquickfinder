import Foundation

/// 应用界面语言（持久化于 `UserDefaults`，Explorer 与 FileList 共用）。
public enum InterfaceLanguage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case system
    case en
    case zhHans = "zh-Hans"

    public var id: String { rawValue }

    /// SPM 资源 bundle 内 `.lproj` 目录名（小写）。
    public var bundleLanguageID: String? {
        switch self {
        case .system: return nil
        case .en: return "en"
        case .zhHans: return "zh-hans"
        }
    }

    /// 语言选项在任意界面语言下的展示名（English / 简体中文 保持原生写法）。
    public var pickerLabel: String {
        switch self {
        case .system:
            return ModuleLocalization.localized("settings.language.system", bundle: .module)
        case .en:
            return "English"
        case .zhHans:
            return "简体中文"
        }
    }
}

/// 跨模块本地化运行时：读取用户语言偏好，从已编译的 `.lproj` 解析字符串。
public enum ModuleLocalization {
    public static let preferenceKey = "app.interfaceLanguage"
    public static let languageDidChange = Notification.Name("ModuleLocalization.languageDidChange")

    public private(set) static var revision = 0

    public static var currentLanguage: InterfaceLanguage {
        let raw = UserDefaults.standard.string(forKey: preferenceKey) ?? InterfaceLanguage.system.rawValue
        return InterfaceLanguage(rawValue: raw) ?? .system
    }

    public static var effectiveLocale: Locale {
        if let identifier = currentLanguage.bundleLanguageID {
            return Locale(identifier: identifier)
        }
        return .autoupdatingCurrent
    }

    @discardableResult
    public static func setLanguage(_ language: InterfaceLanguage) -> Bool {
        let previous = currentLanguage
        guard previous != language else { return false }
        UserDefaults.standard.set(language.rawValue, forKey: preferenceKey)
        revision &+= 1
        applyAppleLanguagesOverride()
        NotificationCenter.default.post(name: languageDidChange, object: nil)
        return true
    }

    /// 启动最早阶段调用，使 AppKit 菜单等与偏好一致。
    public static func applyAppleLanguagesOverride() {
        if let identifier = currentLanguage.bundleLanguageID {
            UserDefaults.standard.set([identifier, "en"], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    public static func localized(_ key: String.LocalizationValue, bundle: Bundle) -> String {
        let target = resolvedLanguageBundle(containing: bundle) ?? bundle
        return String(localized: key, bundle: target)
    }

    /// 从 `.lproj/Localizable.strings` 读取；用于动态键或尚未写入 xcstrings 的条目。
    public static func localizedFromTable(_ key: String, bundle: Bundle) -> String {
        let target = resolvedLanguageBundle(containing: bundle) ?? bundle
        return target.localizedString(forKey: key, value: nil, table: nil)
    }

    /// 按当前语言在 SPM bundle 内查找对应 `.lproj` 子 bundle。
    private static func resolvedLanguageBundle(containing bundle: Bundle) -> Bundle? {
        for languageID in activeBundleLanguageIDs() {
            guard let path = bundle.path(forResource: languageID, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                continue
            }
            return languageBundle
        }
        return nil
    }

    private static func activeBundleLanguageIDs() -> [String] {
        if let fixed = currentLanguage.bundleLanguageID {
            return [fixed, "en"]
        }
        return systemBundleLanguageIDs()
    }

    private static func systemBundleLanguageIDs() -> [String] {
        var ids: [String] = []
        for identifier in Locale.preferredLanguages {
            let normalized = normalizeBundleLanguageID(identifier)
            if !ids.contains(normalized) {
                ids.append(normalized)
            }
        }
        let current = normalizeBundleLanguageID(Locale.autoupdatingCurrent.identifier)
        if !ids.contains(current) {
            ids.append(current)
        }
        if !ids.contains("en") {
            ids.append("en")
        }
        return ids
    }

    /// 将系统 locale 标识映射为 bundle 内 `.lproj` 目录名。
    private static func normalizeBundleLanguageID(_ identifier: String) -> String {
        let lower = identifier.lowercased()
        if lower.hasPrefix("zh") {
            return "zh-hans"
        }
        if lower.hasPrefix("en") {
            return "en"
        }
        return lower.split(separator: "-").first.map(String.init) ?? lower
    }
}
