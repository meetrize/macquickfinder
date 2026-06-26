import Combine
import Foundation

@MainActor
final class ToolbarCustomizationStore: ObservableObject {
    static let shared = ToolbarCustomizationStore()

    @Published private(set) var layout: ToolbarLayoutConfig
    @Published private(set) var isCustomizing = false
    @Published var draftLayout: ToolbarLayoutConfig?

    private var didLoad = false

    private init() {
        layout = .default
    }

    var workingLayout: ToolbarLayoutConfig {
        get { isCustomizing ? (draftLayout ?? layout) : layout }
        set {
            if isCustomizing {
                draftLayout = newValue
            } else {
                layout = newValue
                persist()
            }
        }
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        load()
    }

    func beginCustomization() {
        loadIfNeeded()
        ToolbarItemFrameRegistry.shared.clear()
        draftLayout = layout
        isCustomizing = true
    }

    func commitCustomization() {
        guard isCustomizing, let draftLayout else { return }
        var sanitized = draftLayout
        sanitized.sanitize()
        layout = sanitized
        persist()
        self.draftLayout = nil
        isCustomizing = false
        ToolbarItemFrameRegistry.shared.clear()
    }

    func cancelCustomization() {
        draftLayout = nil
        isCustomizing = false
        ToolbarItemFrameRegistry.shared.clear()
    }

    func resetDraftToDefaults() {
        guard isCustomizing else { return }
        draftLayout = .default
    }

    func addCustomOpenApp(_ action: CustomOpenAppAction) {
        var config = workingLayout
        if let index = config.customOpenApps.firstIndex(where: { $0.id == action.id }) {
            config.customOpenApps[index] = action
        } else {
            config.customOpenApps.append(action)
        }
        workingLayout = config
    }

    func applyDrop(
        payload: ToolbarDragPayload,
        targetZone: ToolbarZone,
        insertIndex: Int
    ) {
        var config = workingLayout

        switch payload.source {
        case .palette:
            config.insertVisible(
                itemID: payload.itemID,
                kind: payload.kind,
                zone: targetZone,
                at: insertIndex
            )
        case .toolbar:
            config.moveVisible(itemID: payload.itemID, toZone: targetZone, at: insertIndex)
        }

        workingLayout = config
    }

    func moveToPalette(itemID: String) {
        var config = workingLayout
        config.removeVisible(itemID: itemID)
        workingLayout = config
    }

    func resetToDefaults() {
        layout = .default
        persist()
        if isCustomizing {
            draftLayout = .default
        }
    }

    private func load() {
        guard let data = UserDefaultsStorage.data(forKey: AppPreferences.Toolbar.layoutConfig) else {
            layout = .default
            return
        }
        guard var decoded = try? JSONDecoder().decode(ToolbarLayoutConfig.self, from: data) else {
            layout = .default
            return
        }
        decoded.sanitize()
        decoded.mergeNewBuiltinItemsFromDefault()
        layout = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        UserDefaultsStorage.set(data, forKey: AppPreferences.Toolbar.layoutConfig)
    }
}
