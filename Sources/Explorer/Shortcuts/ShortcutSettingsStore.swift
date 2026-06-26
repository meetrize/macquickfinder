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

    private init() {
        globalToggleEnabled = UserDefaultsStorage.bool(
            forKey: AppPreferences.Shortcuts.globalToggleEnabled,
            default: true
        )
        globalToggleBinding = Self.loadGlobalToggleBinding()
    }

    func resetGlobalToggleBinding() {
        globalToggleBinding = .defaultGlobalToggle
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
}
