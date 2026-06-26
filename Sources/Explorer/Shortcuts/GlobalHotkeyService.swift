import AppKit
import Carbon
import Foundation

@MainActor
final class GlobalHotkeyService {
    static let shared = GlobalHotkeyService()

    private let hotKeySignature: OSType = 0x4D_51_46_4E // "MQFN"
    private let hotKeyID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    func start() {
        installEventHandlerIfNeeded()
        syncRegistration()
    }

    func syncRegistration() {
        unregister()
        guard ShortcutSettingsStore.shared.globalToggleEnabled else { return }
        register(binding: ShortcutSettingsStore.shared.globalToggleBinding)
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        if status != noErr {
            NSLog("GlobalHotkeyService: failed to install event handler (\(status))")
        }
    }

    private func register(binding: ShortcutBinding) {
        let hotKeyIDValue = EventHotKeyID(signature: hotKeySignature, id: hotKeyID)
        let status = RegisterEventHotKey(
            UInt32(binding.keyCode),
            binding.carbonModifiers,
            hotKeyIDValue,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            NSLog("GlobalHotkeyService: failed to register hotkey (\(status))")
        }
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private static let eventHandlerCallback: EventHandlerUPP = { _, theEvent, userData in
        guard let userData, let theEvent else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            theEvent,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return status }

        let service = Unmanaged<GlobalHotkeyService>
            .fromOpaque(userData)
            .takeUnretainedValue()

        guard hotKeyID.signature == service.hotKeySignature,
              hotKeyID.id == service.hotKeyID else {
            return noErr
        }

        Task { @MainActor in
            AppVisibilityController.toggle()
        }
        return noErr
    }
}
