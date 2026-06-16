import Foundation

public struct FileListSortState: Equatable, Codable, Sendable {
    public var column: FileListColumnID
    public var ascending: Bool
    
    public static let `default` = FileListSortState(column: .name, ascending: true)
    
    public init(column: FileListColumnID, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

public struct FileListPreferences: Equatable, Codable, Sendable {
    public var columns: FileListColumnConfiguration
    public var sort: FileListSortState
    
    public static let `default` = FileListPreferences(
        columns: .default,
        sort: .default
    )
    
    public init(columns: FileListColumnConfiguration, sort: FileListSortState) {
        self.columns = columns
        self.sort = sort
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.columns) {
            columns = try container.decode(FileListColumnConfiguration.self, forKey: .columns)
            sort = try container.decodeIfPresent(FileListSortState.self, forKey: .sort) ?? .default
            return
        }
        
        // 兼容旧版：根对象即列配置 JSON。
        columns = try FileListColumnConfiguration(from: decoder)
        sort = .default
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(columns, forKey: .columns)
        try container.encode(sort, forKey: .sort)
    }
    
    private enum CodingKeys: String, CodingKey {
        case columns
        case sort
    }
    
    public static func normalized(_ preferences: FileListPreferences) -> FileListPreferences {
        var prefs = preferences
        prefs.columns = FileListColumnConfiguration.normalized(prefs.columns)
        
        if !FileListColumnID.allCases.contains(prefs.sort.column) {
            prefs.sort = .default
        }
        return prefs
    }
    
    /// 从 UserDefaults 数据解码；支持新版与旧版列配置格式。
    public static func decode(from data: Data) -> FileListPreferences? {
        guard let decoded = try? JSONDecoder().decode(FileListPreferences.self, from: data) else {
            return nil
        }
        return normalized(decoded)
    }
    
    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
