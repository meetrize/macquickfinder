import Foundation

@MainActor
final class DefaultFileViewerSettingsModel: ObservableObject {
    @Published private(set) var isDefault = false
    @Published private(set) var isFinderDefault = true
    @Published private(set) var currentHandlerName = "Finder"
    @Published private(set) var isApplying = false
    @Published var alertMessage: String?
    @Published var showsRestartReminder = false

    func refresh() {
        let bundleID = DefaultFileViewerManager.effectiveDefaultBundleIdentifier
        isDefault = DefaultFileViewerManager.isDefaultFileViewer
        isFinderDefault = bundleID == DefaultFileViewerManager.finderBundleIdentifier
        currentHandlerName = DefaultFileViewerManager.displayName(for: bundleID)
    }

    func setAsDefault() {
        guard !isApplying else { return }
        isApplying = true
        Task {
            defer { isApplying = false }
            switch await DefaultFileViewerManager.setAsDefaultFileViewer() {
            case .success:
                refresh()
                showsRestartReminder = true
                alertMessage = L10n.Settings.DefaultViewer.setSuccess
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    func restoreFinder() {
        guard !isApplying else { return }
        isApplying = true
        Task {
            defer { isApplying = false }
            switch await DefaultFileViewerManager.restoreFinderAsDefault() {
            case .success:
                refresh()
                showsRestartReminder = true
                alertMessage = L10n.Settings.DefaultViewer.restoreSuccess
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }
}
