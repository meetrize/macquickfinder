import Combine
import Foundation

/// 文件列表列与排序偏好的持久化存储。
public final class FileListPreferencesStore: ObservableObject {
    public static let shared = FileListPreferencesStore()
    
    @Published public private(set) var preferences: FileListPreferences
    
    /// 列配置快捷访问，兼容重构前的 `FileListColumnStore.configuration`。
    public var configuration: FileListColumnConfiguration {
        get { preferences.columns }
        set { updateColumns(newValue) }
    }
    
    public var sort: FileListSortState {
        get { preferences.sort }
        set { updateSort(newValue) }
    }
    
    private let defaults: UserDefaults
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = Self.load(from: defaults)
        resetColumnsToDefaultIfNeeded()
    }
    
    public func save() {
        guard let data = preferences.encoded() else { return }
        defaults.set(data, forKey: FileListStorageKeys.preferences)
    }
    
    public func updateColumns(_ columns: FileListColumnConfiguration) {
        let normalized = FileListColumnConfiguration.normalized(columns)
        guard preferences.columns != normalized else { return }
        preferences = FileListPreferences(columns: normalized, sort: preferences.sort)
        save()
    }
    
    public func updateSort(_ sort: FileListSortState) {
        guard preferences.sort != sort else { return }
        preferences = FileListPreferences(columns: preferences.columns, sort: sort)
        save()
    }
    
    public func replacePreferences(_ newPreferences: FileListPreferences) {
        let normalized = FileListPreferences.normalized(newPreferences)
        guard preferences != normalized else { return }
        preferences = normalized
        save()
    }
    
    public func resetColumnsToDefaultIfNeeded() {
        let allSet = Set(FileListColumnID.allCases)
        if preferences.columns.order.count < FileListColumnID.allCases.count
            || !allSet.isSubset(of: Set(preferences.columns.order)) {
            updateColumns(.default)
        }
    }
    
    /// 兼容旧 API。
    public func resetToDefaultIfNeeded() {
        resetColumnsToDefaultIfNeeded()
    }
    
    // MARK: - Loading
    
    public static func load(from defaults: UserDefaults) -> FileListPreferences {
        if let data = defaults.data(forKey: FileListStorageKeys.preferences),
           let preferences = FileListPreferences.decode(from: data) {
            return preferences
        }
        
        if let legacyData = defaults.data(forKey: FileListStorageKeys.legacyColumns),
           let migrated = migrateLegacyColumnData(legacyData) {
            defaults.set(migrated.encoded(), forKey: FileListStorageKeys.preferences)
            return migrated
        }
        
        return .default
    }
    
    /// 将旧版 `fileListColumns` 数据升级为含排序的完整偏好。
    public static func migrateLegacyColumnData(_ data: Data) -> FileListPreferences? {
        guard let columns = try? JSONDecoder().decode(FileListColumnConfiguration.self, from: data) else {
            return nil
        }
        return FileListPreferences.normalized(
            FileListPreferences(columns: columns, sort: .default)
        )
    }
}

/// 重构过渡期别名，便于现有代码逐步迁移。
public typealias FileListColumnStore = FileListPreferencesStore
