import Foundation

enum ToolbarZone: String, Codable, Hashable {
    case leading
    case main
    case trailing
}

enum ToolbarItemKind: String, Codable, Hashable {
    case builtin
    case openApp
}

enum ToolbarDragSource: String, Codable {
    case toolbar
    case palette
}

struct ToolbarDragPayload: Codable, Equatable {
    var itemID: String
    var kind: ToolbarItemKind
    var source: ToolbarDragSource
}

enum ToolbarBuiltinID: String, Codable, CaseIterable, Identifiable {
    case leftPanel
    case newWindow
    case newTab
    case showAllTabs
    case toggleTabBar
    case preview
    case snippets
    case git
    case recordOperations
    case outputPanel
    case newFolder
    case newFile
    case delete
    case toggleHiddenFiles
    case listView
    case thumbnailView
    case panoramaView
    case thumbnailSizeSlider
    case sortMenu
    case browseSettingsMenu

    var id: String { rawValue }
}

struct ToolbarVisibleEntry: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var zone: ToolbarZone
    var kind: ToolbarItemKind
}

/// 自定义「打开应用」工具栏项的选中项策略（`selectionPolicy`）。
enum OpenAppSelectionPolicy: String, Codable, CaseIterable, Identifiable {
    /// 必须选中文件或文件夹后才能点击；选中项作为打开参数。
    case requireSelection
    /// 无选中也可点击；有选中时传递选中项，无选中时不传参数。
    case passSelectionIfAvailable
    /// 始终将当前浏览的文件夹路径作为参数传给应用。
    case passCurrentDirectory

    var id: String { rawValue }
}

struct CustomOpenAppAction: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var applicationPath: String
    var bundleIdentifier: String?
    var deliveryMode: OpenAppDeliveryMode
    var argumentsTemplate: String?
    var useApplicationIcon: Bool
    var selectionPolicy: OpenAppSelectionPolicy
    var enabled: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        applicationPath: String,
        bundleIdentifier: String? = nil,
        deliveryMode: OpenAppDeliveryMode = .openFiles,
        argumentsTemplate: String? = nil,
        useApplicationIcon: Bool = true,
        selectionPolicy: OpenAppSelectionPolicy = .requireSelection,
        enabled: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.applicationPath = applicationPath
        self.bundleIdentifier = bundleIdentifier
        self.deliveryMode = deliveryMode
        self.argumentsTemplate = argumentsTemplate
        self.useApplicationIcon = useApplicationIcon
        self.selectionPolicy = selectionPolicy
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        applicationPath = try container.decode(String.self, forKey: .applicationPath)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        deliveryMode = try container.decodeIfPresent(OpenAppDeliveryMode.self, forKey: .deliveryMode) ?? .openFiles
        argumentsTemplate = try container.decodeIfPresent(String.self, forKey: .argumentsTemplate)
        useApplicationIcon = try container.decodeIfPresent(Bool.self, forKey: .useApplicationIcon) ?? true
        selectionPolicy = try container.decodeIfPresent(OpenAppSelectionPolicy.self, forKey: .selectionPolicy) ?? .requireSelection
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

enum OpenAppDeliveryMode: String, Codable {
    case openFiles
    case launchWithArguments
}

struct ToolbarLayoutConfig: Codable, Equatable {
    var schemaVersion: Int
    var visibleItems: [ToolbarVisibleEntry]
    var customOpenApps: [CustomOpenAppAction]

    init(
        schemaVersion: Int = 1,
        visibleItems: [ToolbarVisibleEntry],
        customOpenApps: [CustomOpenAppAction] = []
    ) {
        self.schemaVersion = schemaVersion
        self.visibleItems = visibleItems
        self.customOpenApps = customOpenApps
    }

    static var `default`: ToolbarLayoutConfig {
        let builtins: [(ToolbarBuiltinID, ToolbarZone)] = [
            (.leftPanel, .leading),
            (.newWindow, .main),
            (.newTab, .main),
            (.showAllTabs, .main),
            (.toggleTabBar, .main),
            (.preview, .main),
            (.snippets, .main),
            (.git, .main),
            (.recordOperations, .main),
            (.outputPanel, .main),
            (.newFolder, .main),
            (.newFile, .main),
            (.delete, .main),
            (.toggleHiddenFiles, .main),
            (.listView, .main),
            (.thumbnailView, .main),
            (.panoramaView, .main),
            (.thumbnailSizeSlider, .trailing),
            (.sortMenu, .trailing),
            (.browseSettingsMenu, .trailing),
        ]
        return ToolbarLayoutConfig(
            visibleItems: builtins.map {
                ToolbarVisibleEntry(id: $0.0.rawValue, zone: $0.1, kind: .builtin)
            }
        )
    }

    var visibleIDSet: Set<String> {
        Set(visibleItems.map(\.id))
    }

    func items(in zone: ToolbarZone) -> [ToolbarVisibleEntry] {
        visibleItems.filter { $0.zone == zone }
    }

    func customAction(for itemID: String) -> CustomOpenAppAction? {
        guard let uuid = ToolbarItemIdentity.customUUID(from: itemID) else { return nil }
        return customOpenApps.first { $0.id == uuid }
    }

    func paletteItemRefs() -> [ToolbarItemRef] {
        var refs: [ToolbarItemRef] = []
        for builtin in ToolbarBuiltinID.allCases where !visibleIDSet.contains(builtin.rawValue) {
            refs.append(
                ToolbarItemRef(
                    id: builtin.rawValue,
                    kind: .builtin,
                    builtinID: builtin,
                    customActionID: nil
                )
            )
        }
        for action in customOpenApps where action.enabled {
            let itemID = ToolbarItemIdentity.customItemID(action.id)
            guard !visibleIDSet.contains(itemID) else { continue }
            refs.append(
                ToolbarItemRef(
                    id: itemID,
                    kind: .openApp,
                    builtinID: nil,
                    customActionID: action.id
                )
            )
        }
        return refs
    }

    mutating func insertVisible(
        itemID: String,
        kind: ToolbarItemKind,
        zone: ToolbarZone,
        at index: Int
    ) {
        visibleItems.removeAll { $0.id == itemID }
        var zoneItems = items(in: zone)
        let clamped = max(0, min(index, zoneItems.count))
        zoneItems.insert(ToolbarVisibleEntry(id: itemID, zone: zone, kind: kind), at: clamped)
        replaceZone(zone, with: zoneItems)
    }

    mutating func removeVisible(itemID: String) {
        visibleItems.removeAll { $0.id == itemID }
    }

    mutating func moveVisible(itemID: String, toZone zone: ToolbarZone, at index: Int) {
        guard let entry = visibleItems.first(where: { $0.id == itemID }) else { return }
        insertVisible(itemID: entry.id, kind: entry.kind, zone: zone, at: index)
    }

    mutating func sanitize() {
        let knownBuiltin = Set(ToolbarBuiltinID.allCases.map(\.rawValue))
        var cleaned: [ToolbarVisibleEntry] = []
        var seen = Set<String>()

        for entry in visibleItems {
            guard !seen.contains(entry.id) else { continue }
            switch entry.kind {
            case .builtin:
                guard knownBuiltin.contains(entry.id) else { continue }
            case .openApp:
                guard customAction(for: entry.id) != nil else { continue }
            }
            cleaned.append(entry)
            seen.insert(entry.id)
        }

        customOpenApps = customOpenApps.filter(\.enabled)
        visibleItems = cleaned
        schemaVersion = 1
    }

    /// 从磁盘加载后，将新版本新增的内置项补进布局（不恢复用户已隐藏项）。
    mutating func mergeNewBuiltinItemsFromDefault() {
        var seen = visibleIDSet
        for entry in Self.default.visibleItems where !seen.contains(entry.id) {
            insertMergedDefaultEntry(entry)
            seen.insert(entry.id)
        }
    }

    private mutating func insertMergedDefaultEntry(_ entry: ToolbarVisibleEntry) {
        guard let defaultIndex = Self.default.visibleItems.firstIndex(where: { $0.id == entry.id }) else {
            visibleItems.append(entry)
            return
        }

        let defaultOrder = Self.default.visibleItems
        for preceding in defaultOrder[..<defaultIndex].reversed() {
            guard let anchorIndex = visibleItems.lastIndex(where: {
                $0.id == preceding.id && $0.zone == entry.zone
            }) else { continue }
            visibleItems.insert(entry, at: anchorIndex + 1)
            return
        }

        if let zoneFirstIndex = visibleItems.firstIndex(where: { $0.zone == entry.zone }) {
            visibleItems.insert(entry, at: zoneFirstIndex)
        } else {
            visibleItems.append(entry)
        }
    }

    private mutating func replaceZone(_ zone: ToolbarZone, with entries: [ToolbarVisibleEntry]) {
        var rebuilt: [ToolbarVisibleEntry] = []
        for candidate in [ToolbarZone.leading, .main, .trailing] {
            if candidate == zone {
                rebuilt.append(contentsOf: entries)
            } else {
                rebuilt.append(contentsOf: items(in: candidate))
            }
        }
        visibleItems = rebuilt
    }
}

struct ToolbarItemRef: Identifiable, Equatable, Hashable {
    var id: String
    var kind: ToolbarItemKind
    var builtinID: ToolbarBuiltinID?
    var customActionID: UUID?
}

enum ToolbarItemIdentity {
    static let customPrefix = "custom:"
    static let accessibilityPrefix = "toolbar.item."

    static func customItemID(_ uuid: UUID) -> String {
        customPrefix + uuid.uuidString
    }

    static func customUUID(from itemID: String) -> UUID? {
        guard itemID.hasPrefix(customPrefix) else { return nil }
        return UUID(uuidString: String(itemID.dropFirst(customPrefix.count)))
    }

    static func accessibilityIdentifier(for itemID: String) -> String {
        accessibilityPrefix + itemID
    }

    static func itemID(fromAccessibilityIdentifier identifier: String) -> String? {
        guard identifier.hasPrefix(accessibilityPrefix) else { return nil }
        let itemID = String(identifier.dropFirst(accessibilityPrefix.count))
        return itemID.isEmpty ? nil : itemID
    }
}

enum ToolbarActionError: Error, Equatable {
    case requiresSelection
    case applicationMissing(String)
    case unsupportedDeliveryMode
}

extension ToolbarDragPayload {
    var pasteboardString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func fromPasteboardString(_ value: String) -> ToolbarDragPayload? {
        guard let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ToolbarDragPayload.self, from: data)
    }

    static func fromPasteboardItem(_ item: NSSecureCoding?) -> ToolbarDragPayload? {
        if let string = item as? String {
            return fromPasteboardString(string)
        }
        if let string = item as? NSString {
            return fromPasteboardString(string as String)
        }
        if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
            return fromPasteboardString(string)
        }
        return nil
    }
}
