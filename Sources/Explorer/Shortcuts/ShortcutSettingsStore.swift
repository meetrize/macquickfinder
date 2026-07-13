import Combine
import Foundation

@MainActor
final class ShortcutSettingsStore: ObservableObject {
    static let shared = ShortcutSettingsStore()

    @Published var globalToggleEnabled: Bool {
        didSet {
            UserDefaultsStorage.set(globalToggleEnabled, forKey: AppPreferences.Shortcuts.globalToggleEnabled)
            GlobalHotkeyService.shared.syncRegistration()
        }
    }

    @Published var globalToggleBinding: ShortcutBinding {
        didSet {
            persistGlobalToggleBinding()
            GlobalHotkeyService.shared.syncRegistration()
        }
    }

    @Published var newTabBinding: ShortcutBinding {
        didSet { persistNewTabBinding() }
    }

    @Published var copyPathBinding: ShortcutBinding {
        didSet { persistCopyPathBinding() }
    }

    @Published var previewTextEditBinding: ShortcutBinding {
        didSet { persistPreviewTextEditBinding() }
    }

    private init() {
        globalToggleEnabled = UserDefaultsStorage.bool(
            forKey: AppPreferences.Shortcuts.globalToggleEnabled,
            default: true
        )
        globalToggleBinding = Self.loadGlobalToggleBinding()
        newTabBinding = Self.loadNewTabBinding()
        copyPathBinding = Self.loadCopyPathBinding()
        previewTextEditBinding = Self.loadPreviewTextEditBinding()
    }

    func resetGlobalToggleBinding() {
        globalToggleBinding = .defaultGlobalToggle
    }

    func resetNewTabBinding() {
        newTabBinding = .defaultNewTab
    }

    func resetCopyPathBinding() {
        copyPathBinding = .defaultCopyPath
    }

    func resetPreviewTextEditBinding() {
        previewTextEditBinding = .defaultPreviewTextEdit
    }

    private func persistGlobalToggleBinding() {
        UserDefaultsStorage.set(Int(globalToggleBinding.keyCode), forKey: AppPreferences.Shortcuts.globalToggleKeyCode)
        UserDefaultsStorage.set(Int(globalToggleBinding.modifiers), forKey: AppPreferences.Shortcuts.globalToggleModifiers)
    }

    private static func loadGlobalToggleBinding() -> ShortcutBinding {
        guard UserDefaults.standard.object(forKey: AppPreferences.Shortcuts.globalToggleKeyCode) != nil else {
            return .defaultGlobalToggle
        }
        let keyCode = UInt16(UserDefaultsStorage.int(
            forKey: AppPreferences.Shortcuts.globalToggleKeyCode,
            default: Int(ShortcutBinding.defaultGlobalToggle.keyCode)
        ))
        let modifiers = UInt(UserDefaultsStorage.int(
            forKey: AppPreferences.Shortcuts.globalToggleModifiers,
            default: Int(ShortcutBinding.defaultGlobalToggle.modifiers)
        ))
        return ShortcutBinding(keyCode: keyCode, modifiers: modifiers)
    }

    private func persistNewTabBinding() {
        UserDefaultsStorage.set(Int(newTabBinding.keyCode), forKey: AppPreferences.Shortcuts.newTabKeyCode)
        UserDefaultsStorage.set(Int(newTabBinding.modifiers), forKey: AppPreferences.Shortcuts.newTabModifiers)
    }

    private static func loadNewTabBinding() -> ShortcutBinding {
        guard UserDefaults.standard.object(forKey: AppPreferences.Shortcuts.newTabKeyCode) != nil else {
            return .defaultNewTab
        }
        let keyCode = UInt16(UserDefaultsStorage.int(
            forKey: AppPreferences.Shortcuts.newTabKeyCode,
            default: Int(ShortcutBinding.defaultNewTab.keyCode)
        ))
        let modifiers = UInt(UserDefaultsStorage.int(
            forKey: AppPreferences.Shortcuts.newTabModifiers,
            default: Int(ShortcutBinding.defaultNewTab.modifiers)
        ))
        return ShortcutBinding(keyCode: keyCode, modifiers: modifiers)
    }

    private func persistCopyPathBinding() {
        UserDefaultsStorage.set(Int(copyPathBinding.keyCode), forKey: AppPreferences.Shortcuts.copyPathKeyCode)
        UserDefaultsStorage.set(Int(copyPathBinding.modifiers), forKey: AppPreferences.Shortcuts.copyPathModifiers)
    }

    private static func loadCopyPathBinding() -> ShortcutBinding {
        guard UserDefaults.standard.object(forKey: AppPreferences.Shortcuts.copyPathKeyCode) != nil else {
            return .defaultCopyPath
        }
        let keyCode = UInt16(UserDefaultsStorage.int(
            forKey: AppPreferences.Shortcuts.copyPathKeyCode,
            default: Int(ShortcutBinding.defaultCopyPath.keyCode)
        ))
        let modifiers = UInt(UserDefaultsStorage.int(
            forKey: AppPreferences.Shortcuts.copyPathModifiers,
            default: Int(ShortcutBinding.defaultCopyPath.modifiers)
        ))
        return ShortcutBinding(keyCode: keyCode, modifiers: modifiers)
    }

    private func persistPreviewTextEditBinding() {
        UserDefaultsStorage.set(Int(previewTextEditBinding.keyCode), forKey: AppPreferences.Shortcuts.previewTextEditKeyCode)
        UserDefaultsStorage.set(Int(previewTextEditBinding.modifiers), forKey: AppPreferences.Shortcuts.previewTextEditModifiers)
    }

    private static func loadPreviewTextEditBinding() -> ShortcutBinding {
        guard UserDefaults.standard.object(forKey: AppPreferences.Shortcuts.previewTextEditKeyCode) != nil else {
            return .defaultPreviewTextEdit
        }
        let keyCode = UInt16(UserDefaultsStorage.int(
            forKey: AppPreferences.Shortcuts.previewTextEditKeyCode,
            default: Int(ShortcutBinding.defaultPreviewTextEdit.keyCode)
        ))
        let modifiers = UInt(UserDefaultsStorage.int(
            forKey: AppPreferences.Shortcuts.previewTextEditModifiers,
            default: Int(ShortcutBinding.defaultPreviewTextEdit.modifiers)
        ))
        return ShortcutBinding(keyCode: keyCode, modifiers: modifiers)
    }
}
