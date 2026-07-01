import Foundation

@MainActor
final class DefaultPreviewHandlerSettingsModel: ObservableObject {
    struct GroupState: Equatable {
        var isDefault: Bool
        var currentHandlerName: String
    }

    @Published private(set) var groupStates: [PreviewHandlerGroup: GroupState] = [:]
    @Published private(set) var isApplying = false
    @Published var alertMessage: String?
    @Published var showsRestartReminder = false

    init() {
        refresh()
    }

    func refresh() {
        var states: [PreviewHandlerGroup: GroupState] = [:]
        for group in PreviewHandlerGroup.allCases {
            states[group] = GroupState(
                isDefault: DefaultPreviewHandlerManager.isDefault(for: group),
                currentHandlerName: DefaultPreviewHandlerManager.currentHandlerName(for: group)
            )
        }
        groupStates = states
    }

    func setAsDefault(_ group: PreviewHandlerGroup) {
        guard !isApplying else { return }
        isApplying = true
        Task {
            defer { isApplying = false }
            switch await DefaultPreviewHandlerManager.setAsDefault(for: group) {
            case .success:
                refresh()
                showsRestartReminder = true
                alertMessage = L10n.Settings.Preview.HandlerGroup.setSuccess(group.displayName)
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    func restoreSystemDefault(_ group: PreviewHandlerGroup) {
        guard !isApplying else { return }
        isApplying = true
        Task {
            defer { isApplying = false }
            switch await DefaultPreviewHandlerManager.restoreSystemDefault(for: group) {
            case .success:
                refresh()
                showsRestartReminder = true
                alertMessage = L10n.Settings.Preview.HandlerGroup.restoreSuccess(group.displayName)
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }
}
