import Foundation

@MainActor
final class DefaultImageViewerSettingsModel: ObservableObject {
    @Published private(set) var isDefault = false
    @Published private(set) var isPreviewDefault = true
    @Published private(set) var currentHandlerName = "Preview"
    @Published private(set) var isApplying = false
    @Published var alertMessage: String?
    @Published var showsRestartReminder = false

    func refresh() {
        let bundleID = DefaultImageViewerManager.effectiveDefaultBundleIdentifier
        isDefault = DefaultImageViewerManager.isDefaultImageViewer
        isPreviewDefault = bundleID == DefaultImageViewerManager.previewBundleIdentifier
        currentHandlerName = DefaultImageViewerManager.displayName(for: bundleID)
    }

    func setAsDefault() {
        guard !isApplying else { return }
        isApplying = true
        Task {
            defer { isApplying = false }
            switch await DefaultImageViewerManager.setAsDefaultImageViewer() {
            case .success:
                refresh()
                showsRestartReminder = true
                alertMessage = L10n.Settings.DefaultImageViewer.setSuccess
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    func restorePreview() {
        guard !isApplying else { return }
        isApplying = true
        Task {
            defer { isApplying = false }
            switch await DefaultImageViewerManager.restorePreviewAsDefault() {
            case .success:
                refresh()
                showsRestartReminder = true
                alertMessage = L10n.Settings.DefaultImageViewer.restoreSuccess
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }
}
