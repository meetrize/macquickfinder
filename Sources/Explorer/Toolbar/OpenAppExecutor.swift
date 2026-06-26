import AppKit
import Foundation

struct ToolbarActionContext {
    let cwd: String
    let selectedItems: [FileItem]
}

enum OpenAppExecutor {
    @MainActor
    static func run(_ action: CustomOpenAppAction, context: ToolbarActionContext) throws {
        guard action.enabled else { return }

        let appURL = URL(fileURLWithPath: action.applicationPath)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw ToolbarActionError.applicationMissing(action.displayName)
        }

        switch action.deliveryMode {
        case .openFiles:
            let urls = context.selectedItems.map(\.url)
            let configuration = NSWorkspace.OpenConfiguration()
            switch action.selectionPolicy {
            case .requireSelection:
                guard !urls.isEmpty else { throw ToolbarActionError.requiresSelection }
                NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration)
            case .passSelectionIfAvailable:
                if urls.isEmpty {
                    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
                } else {
                    NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration)
                }
            }
        case .launchWithArguments:
            throw ToolbarActionError.unsupportedDeliveryMode
        }
    }

    @MainActor
    static func presentApplicationMissingAlert(name: String) {
        let alert = NSAlert()
        alert.messageText = L10n.Toolbar.Error.appMissingTitle
        alert.informativeText = L10n.Toolbar.Error.appMissing(name)
        alert.alertStyle = .warning
        alert.runModal()
    }
}
