import Foundation

@MainActor
enum OutputPanelPresenter {
    static func showIfAutoEnabled() {
        guard SnippetsSettings.shared.autoShowOutputPanelOnShellRun else { return }
        guard let layout = ActiveWindowLayoutCenter.shared.keyWindowLayout else { return }
        ActiveWindowLayoutCenter.shared.showOutputPanel(on: layout)
    }
}
