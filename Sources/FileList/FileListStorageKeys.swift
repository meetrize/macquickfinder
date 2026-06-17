import Foundation

public enum FileListStorageKeys {
    public static let preferences = "fileListPreferences"
    /// 旧版仅持久化列配置的键，用于迁移。
    public static let legacyColumns = "fileListColumns"
    public static let viewMode = "explorer.fileList.viewMode"
    public static let thumbnailCellSize = "explorer.fileList.thumbnailCellSize"
}
