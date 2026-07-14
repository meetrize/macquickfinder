import AppKit
import Foundation

enum OpenShortcutExecutor {
    @MainActor
    static func run(
        _ action: CustomOpenShortcutAction,
        navigate: (String) -> Void
    ) throws {
        guard action.enabled else { return }

        let url = URL(fileURLWithPath: action.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ToolbarActionError.shortcutMissing(action.displayName)
        }

        switch action.targetKind {
        case .folder:
            navigate(url.path)
        case .file, .application:
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    static func presentMissingAlert(
        name: String,
        onRemove: (() -> Void)?
    ) {
        let alert = NSAlert()
        alert.messageText = L10n.Toolbar.Error.shortcutMissingTitle
        alert.informativeText = L10n.Toolbar.Error.shortcutMissing(name)
        alert.alertStyle = .warning
        if onRemove != nil {
            alert.addButton(withTitle: L10n.Toolbar.shortcutRemove)
        }
        alert.addButton(withTitle: L10n.Action.ok)
        let response = alert.runModal()
        if onRemove != nil, response == .alertFirstButtonReturn {
            onRemove?()
        }
    }
}
