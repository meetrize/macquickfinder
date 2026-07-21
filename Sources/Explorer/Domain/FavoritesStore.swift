import Foundation
import SwiftUI
import FileList

enum FavoriteKind: String, Codable, Equatable {
    case home
    case desktop
    case documents
    case downloads
    case custom
}

struct FavoriteItem: Codable, Identifiable, Equatable {
    let path: String
    var kind: FavoriteKind
    var customName: String?
    let icon: String

    var id: String { path }

    var displayName: String {
        switch kind {
        case .home:
            return L10n.SystemFolder.home
        case .desktop:
            return L10n.SystemFolder.desktop
        case .documents:
            return L10n.SystemFolder.documents
        case .downloads:
            return L10n.SystemFolder.downloads
        case .custom:
            return customName ?? (path as NSString).lastPathComponent
        }
    }

    init(path: String, kind: FavoriteKind, customName: String? = nil, icon: String) {
        self.path = path
        self.kind = kind
        self.customName = customName
        self.icon = icon
    }

    /// 兼容旧版测试与 `name` 字段持久化数据。
    init(path: String, name: String, icon: String) {
        let migrated = Self.migrateKind(fromLegacyName: name, path: path)
        self.path = path
        self.kind = migrated.kind
        self.customName = migrated.customName
        self.icon = icon
    }

    private enum CodingKeys: String, CodingKey {
        case path
        case kind
        case customName
        case icon
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        icon = try container.decode(String.self, forKey: .icon)

        if let kind = try container.decodeIfPresent(FavoriteKind.self, forKey: .kind) {
            self.kind = kind
            customName = try container.decodeIfPresent(String.self, forKey: .customName)
        } else {
            let legacyName = try container.decode(String.self, forKey: .name)
            let migrated = Self.migrateKind(fromLegacyName: legacyName, path: path)
            kind = migrated.kind
            customName = migrated.customName
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(kind, forKey: .kind)
        if kind == .custom {
            try container.encodeIfPresent(customName, forKey: .customName)
        }
        try container.encode(icon, forKey: .icon)
    }

    private static func migrateKind(fromLegacyName name: String, path: String) -> (kind: FavoriteKind, customName: String?) {
        switch name {
        case "Home":
            return (.home, nil)
        case "Desktop":
            return (.desktop, nil)
        case "Documents":
            return (.documents, nil)
        case "Downloads":
            return (.downloads, nil)
        default:
            return (.custom, name)
        }
    }

    /// 系统收藏项解析为当前用户真实目录（如 iCloud 桌面），供导航与拖放使用。
    var resolvedDirectoryPath: String {
        switch kind {
        case .home:
            return FileManager.default.homeDirectoryForCurrentUser.path
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? path
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? path
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? path
        case .custom:
            return path
        }
    }
}

@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    
    @Published private(set) var items: [FavoriteItem] = []
    
    private init() {
        load()
    }
    
    static func defaultItems() -> [FavoriteItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            FavoriteItem(path: home, kind: .home, icon: "house"),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Desktop"),
                kind: .desktop,
                icon: "desktopcomputer"
            ),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Documents"),
                kind: .documents,
                icon: "doc"
            ),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Downloads"),
                kind: .downloads,
                icon: "arrow.down.circle"
            )
        ]
    }
    
    func contains(path: String) -> Bool {
        let normalized = FavoritePathNormalization.standardize(path)
        return items.contains { FavoritePathNormalization.pathsRepresentSameLocation($0.path, normalized) }
    }

    func addDirectory(at path: String, insertBefore: Int? = nil) {
        let normalized = FavoritePathNormalization.standardize(path)
        guard FileListApplicationBundle.isFavoriteableDirectory(path: normalized),
              !contains(path: normalized) else { return }
        let name = (normalized as NSString).lastPathComponent
        let item = FavoriteItem(path: normalized, kind: .custom, customName: name, icon: "folder")
        if let insertBefore {
            let index = min(max(insertBefore, 0), items.count)
            items.insert(item, at: index)
        } else {
            items.append(item)
        }
        save()
    }
    
    func remove(path: String) {
        let normalized = FavoritePathNormalization.standardize(path)
        items.removeAll { FavoritePathNormalization.pathsRepresentSameLocation($0.path, normalized) }
        save()
    }
    
    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }
    
    func moveItem(withPath draggedPath: String, toInsertBefore insertIndex: Int) {
        let normalizedDragged = FavoritePathNormalization.standardize(draggedPath)
        guard let fromIndex = items.firstIndex(where: {
            FavoritePathNormalization.pathsRepresentSameLocation($0.path, normalizedDragged)
        }) else {
            return
        }
        
        var targetIndex = insertIndex
        if fromIndex < targetIndex {
            targetIndex -= 1
        }
        guard targetIndex != fromIndex else { return }
        
        let item = items.remove(at: fromIndex)
        let clampedIndex = max(0, min(targetIndex, items.count))
        items.insert(item, at: clampedIndex)
        save()
    }
    
    static func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        FavoritePathNormalization.pathsRepresentSameLocation(lhs, rhs)
    }

    private func load() {
        guard let data = UserDefaultsStorage.data(forKey: AppPreferences.Data.favorites),
              let decoded = try? JSONDecoder().decode([FavoriteItem].self, from: data) else {
            items = Self.defaultItems()
            return
        }
        items = decoded
        migrateLegacyItemsIfNeeded()
    }

    private func migrateLegacyItemsIfNeeded() {
        guard let data = UserDefaultsStorage.data(forKey: AppPreferences.Data.favorites),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        let needsMigration = json.contains { $0["kind"] == nil }
        if needsMigration {
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaultsStorage.set(data, forKey: AppPreferences.Data.favorites)
    }
}
