import Foundation

/// 按文件扩展名分桶记录「打开方式」最近选用的应用（MRU，最新在前）。
enum OpenWithRecentsStore {
    static let maxAppsPerType = 20
    static let maxTypes = 100

    private static var memoryCache: [String: [String]]?
    private static var memoryCacheIsFresh = false

    static func fileTypeKey(for fileURL: URL) -> String {
        fileURL.pathExtension.lowercased()
    }

    static func normalizedAppPath(_ appURL: URL) -> String {
        appURL.resolvingSymlinksInPath().path
    }

    static func recentAppPaths(
        forFileURL fileURL: URL,
        defaults: UserDefaults = .standard
    ) -> [String] {
        recentAppPaths(forTypeKey: fileTypeKey(for: fileURL), defaults: defaults)
    }

    static func recentAppPaths(
        forTypeKey typeKey: String,
        defaults: UserDefaults = .standard
    ) -> [String] {
        load(from: defaults)[typeKey] ?? []
    }

    static func record(
        appURL: URL,
        forFileURL fileURL: URL,
        defaults: UserDefaults = .standard
    ) {
        record(
            appPath: normalizedAppPath(appURL),
            forTypeKey: fileTypeKey(for: fileURL),
            defaults: defaults
        )
    }

    static func record(
        appPath: String,
        forTypeKey typeKey: String,
        defaults: UserDefaults = .standard
    ) {
        guard !appPath.isEmpty else { return }
        var byType = load(from: defaults)
        var list = byType[typeKey] ?? []
        list.removeAll { $0 == appPath }
        list.insert(appPath, at: 0)
        if list.count > maxAppsPerType {
            list = Array(list.prefix(maxAppsPerType))
        }
        byType[typeKey] = list
        if byType.count > maxTypes {
            let excess = byType.count - maxTypes
            let removable = byType.keys.filter { $0 != typeKey }.prefix(excess)
            for key in removable {
                byType.removeValue(forKey: key)
            }
        }
        if defaults === UserDefaults.standard {
            memoryCache = byType
            memoryCacheIsFresh = true
        }
        save(byType, to: defaults)
    }

    /// 将候选应用路径按 MRU 排序：有记录的靠前（越近越前），无记录的按显示名回退比较。
    static func sortAppURLsByRecents(
        _ appURLs: [URL],
        recentPaths: [String],
        displayName: (URL) -> String
    ) -> [URL] {
        let rankByPath: [String: Int] = Dictionary(
            uniqueKeysWithValues: recentPaths.enumerated().map { ($0.element, $0.offset) }
        )
        return appURLs.sorted { lhs, rhs in
            let lhsPath = normalizedAppPath(lhs)
            let rhsPath = normalizedAppPath(rhs)
            let lhsRank = rankByPath[lhsPath]
            let rhsRank = rankByPath[rhsPath]
            switch (lhsRank, rhsRank) {
            case let (l?, r?):
                if l != r { return l < r }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }
            return displayName(lhs).localizedStandardCompare(displayName(rhs)) == .orderedAscending
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> [String: [String]] {
        if defaults === UserDefaults.standard, memoryCacheIsFresh, let memoryCache {
            return memoryCache
        }
        guard let data = UserDefaultsStorage.data(forKey: AppPreferences.OpenWith.recentsByType, in: defaults),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            if defaults === UserDefaults.standard {
                memoryCache = [:]
                memoryCacheIsFresh = true
            }
            return [:]
        }
        if defaults === UserDefaults.standard {
            memoryCache = decoded
            memoryCacheIsFresh = true
        }
        return decoded
    }

    /// 测试用：清空标准 UserDefaults 上的内存缓存。
    static func resetCacheForTesting() {
        memoryCache = nil
        memoryCacheIsFresh = false
    }

    // MARK: - Private

    private static func save(_ byType: [String: [String]], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(byType) else { return }
        UserDefaultsStorage.set(data, forKey: AppPreferences.OpenWith.recentsByType, in: defaults)
    }
}
