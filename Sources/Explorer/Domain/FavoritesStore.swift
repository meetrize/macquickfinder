import Foundation
import SwiftUI

struct FavoriteItem: Codable, Identifiable, Equatable {
    let path: String
    let name: String
    let icon: String
    
    var id: String { path }
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
            FavoriteItem(path: home, name: "Home", icon: "house"),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Desktop"),
                name: "Desktop",
                icon: "desktopcomputer"
            ),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Documents"),
                name: "Documents",
                icon: "doc"
            ),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Downloads"),
                name: "Downloads",
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
        guard !contains(path: normalized) else { return }
        let name = (normalized as NSString).lastPathComponent
        let item = FavoriteItem(path: normalized, name: name, icon: "folder")
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
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaultsStorage.set(data, forKey: AppPreferences.Data.favorites)
    }
}
