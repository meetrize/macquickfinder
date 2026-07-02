import Foundation

@MainActor
enum OutputPanelPresenter {
    static func showIfAutoEnabled(on layout: ExplorerWindowLayoutState? = nil) {
        guard SnippetsSettings.shared.autoShowOutputPanelOnShellRun else { return }
        guard let target = ActiveWindowLayoutCenter.shared.resolveLayoutForOutputPanel(preferred: layout) else { return }
        ActiveWindowLayoutCenter.shared.showOutputPanel(on: target)
    }
}
