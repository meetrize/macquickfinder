import Foundation

/// FileList 模块持久化键（字符串源；Explorer 侧请通过 `AppPreferences.FileList` 引用）。
public enum FileListStorageKeys {
    public static let preferences = "fileListPreferences"
    /// 旧版仅持久化列配置的键，用于迁移。
    public static let legacyColumns = "fileListColumns"
    public static let viewMode = "explorer.fileList.viewMode"
    public static let thumbnailLayoutMode = "explorer.fileList.thumbnailLayoutMode"
    public static let thumbnailCellSize = "explorer.fileList.thumbnailCellSize"
    public static let rowHoverHighlight = "explorer.fileList.rowHoverHighlight"
}
