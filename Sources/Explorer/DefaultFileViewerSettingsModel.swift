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
                alertMessage = "已将 MeoFind 设为默认文件夹查看器。请注销并重新登录（或重启）后，更改才会在全部场景中生效。"
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
                alertMessage = "已恢复 Finder 为默认文件夹查看器。请注销并重新登录（或重启）后，更改才会在全部场景中生效。"
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }
}
