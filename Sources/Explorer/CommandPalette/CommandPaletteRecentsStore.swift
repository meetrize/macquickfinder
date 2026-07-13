import Foundation

enum CommandPaletteRecentsStore {
    private static let maxCount = 10
    private static var memoryCache: [CommandPaletteID]?
    private static var memoryCacheIsFresh = false

    static func cachedLoad() -> [CommandPaletteID] {
        if memoryCacheIsFresh, let memoryCache {
            return memoryCache
        }
        let loaded = loadFromDefaults()
        memoryCache = loaded
        memoryCacheIsFresh = true
        return loaded
    }

    static func record(_ id: CommandPaletteID) {
        var recents = cachedLoad().filter { $0 != id }
        recents.insert(id, at: 0)
        if recents.count > maxCount {
            recents = Array(recents.prefix(maxCount))
        }
        memoryCache = recents
        memoryCacheIsFresh = true
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: AppPreferences.CommandPalette.recents)
        }
    }

    private static func loadFromDefaults() -> [CommandPaletteID] {
        guard let data = UserDefaults.standard.data(forKey: AppPreferences.CommandPalette.recents),
              let ids = try? JSONDecoder().decode([CommandPaletteID].self, from: data) else {
            return []
        }
        return ids
    }
}
