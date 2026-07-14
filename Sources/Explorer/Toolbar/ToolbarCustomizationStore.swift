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

    func deleteCustomOpenApp(id: UUID) {
        var config = workingLayout
        let itemID = ToolbarItemIdentity.customItemID(id)
        config.customOpenApps.removeAll { $0.id == id }
        config.removeVisible(itemID: itemID)
        workingLayout = config
    }

    func deleteCustomOpenShortcut(id: UUID) {
        var config = workingLayout
        let itemID = ToolbarItemIdentity.shortcutItemID(id)
        config.customOpenShortcuts.removeAll { $0.id == id }
        config.removeVisible(itemID: itemID)
        workingLayout = config
    }

    /// 将 Finder / 文件列表拖入的路径转为工具栏快捷方式并插入指定位置。
    /// - Returns: 实际新增或从上栏外调入的项数。
    @discardableResult
    func addOpenShortcuts(urls: [URL], zone: ToolbarZone, at index: Int) -> Int {
        var config = workingLayout
        var insertAt = index
        var added = 0

        for url in urls {
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            guard FileManager.default.fileExists(atPath: resolved.path) else { continue }

            if let existing = config.shortcut(matchingPath: resolved.path) {
                let itemID = ToolbarItemIdentity.shortcutItemID(existing.id)
                guard !config.visibleIDSet.contains(itemID) else { continue }
                config.insertVisible(
                    itemID: itemID,
                    kind: .openShortcut,
                    zone: zone,
                    at: insertAt
                )
                insertAt += 1
                added += 1
                continue
            }

            guard config.visibleShortcutCount < ToolbarLayoutConfig.maxVisibleShortcuts else {
                break
            }

            let action = CustomOpenShortcutAction.make(from: resolved)
            config.customOpenShortcuts.append(action)
            let itemID = ToolbarItemIdentity.shortcutItemID(action.id)
            config.insertVisible(
                itemID: itemID,
                kind: .openShortcut,
                zone: zone,
                at: insertAt
            )
            insertAt += 1
            added += 1
        }

        workingLayout = config
        return added
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
