import AppKit
import SwiftUI

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var openHandler: (() -> Void)?
    private(set) var pendingPrefillExtension: String?

    private init() {}

    func registerOpenHandler(_ handler: @escaping () -> Void) {
        openHandler = handler
    }

    func stagePrefillExtension(_ ext: String?) {
        pendingPrefillExtension = ext
    }

    func consumePendingPrefillExtension() -> String? {
        defer { pendingPrefillExtension = nil }
        return pendingPrefillExtension
    }

    func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let openHandler {
            openHandler()
            return
        }
        openLegacySettingsWindow()
    }

    private func openLegacySettingsWindow() {
        let settingsSelector = Selector(("showSettingsWindow:"))
        if NSApp.sendAction(settingsSelector, to: nil, from: nil) {
            return
        }
        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

@available(macOS 14.0, *)
struct SettingsWindowOpenBridge: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                SettingsWindowPresenter.shared.registerOpenHandler {
                    openSettings()
                }
            }
    }
}

extension View {
    @ViewBuilder
    func settingsWindowOpenBridge() -> some View {
        if #available(macOS 14.0, *) {
            background(SettingsWindowOpenBridge())
        } else {
            self
        }
    }
}

@MainActor
func openPreviewSettings(prefillExtension: String? = nil) {
    SettingsWindowPresenter.shared.stagePrefillExtension(prefillExtension)

    if let prefillExtension, !prefillExtension.isEmpty {
        NotificationCenter.default.post(
            name: .openPreviewSettingsRequested,
            object: nil,
            userInfo: ["extension": prefillExtension]
        )
    } else {
        NotificationCenter.default.post(name: .openPreviewSettingsRequested, object: nil)
    }

    SettingsWindowPresenter.shared.openSettingsWindow()
}
