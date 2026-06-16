import Foundation

/// 文件列表行展示模型（与 Explorer 的 `FileItem` 解耦，供 NSTableView 使用）。
public struct FileListRow: Equatable, Sendable, Identifiable {
    /// 用于识别「..」行，与 Explorer 的 `FileItem.parentDirectoryID` 保持一致。
    public static let parentDirectoryID = "__parent_directory__"
    
    public let id: String
    public let name: String
    public let fileType: String
    public let sizeDisplay: String
    public let dateDisplay: String
    public let size: Int64
    public let modificationDate: Date
    public let isDirectory: Bool
    public let isHidden: Bool
    public let isParentDirectoryEntry: Bool
    /// 用于 `NSWorkspace` 取图标的路径。
    public let iconPath: String
    
    public init(
        id: String,
        name: String,
        fileType: String,
        sizeDisplay: String,
        dateDisplay: String,
        size: Int64,
        modificationDate: Date,
        isDirectory: Bool,
        isHidden: Bool,
        isParentDirectoryEntry: Bool,
        iconPath: String
    ) {
        self.id = id
        self.name = name
        self.fileType = fileType
        self.sizeDisplay = sizeDisplay
        self.dateDisplay = dateDisplay
        self.size = size
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
        self.isHidden = isHidden
        self.isParentDirectoryEntry = isParentDirectoryEntry
        self.iconPath = iconPath
    }
    
    /// 除 Size 列展示字段外，是否与另一行相同（用于判断仅需刷新大小列）。
    public func hasSameStaticContent(as other: FileListRow) -> Bool {
        id == other.id
            && name == other.name
            && fileType == other.fileType
            && dateDisplay == other.dateDisplay
            && modificationDate == other.modificationDate
            && isDirectory == other.isDirectory
            && isHidden == other.isHidden
            && isParentDirectoryEntry == other.isParentDirectoryEntry
            && iconPath == other.iconPath
    }
    
    func withDirectorySizeDisplay(_ info: DirectorySizeDisplayInfo) -> FileListRow {
        guard isDirectory, !isParentDirectoryEntry else { return self }
        return FileListRow(
            id: id,
            name: name,
            fileType: fileType,
            sizeDisplay: info.text,
            dateDisplay: dateDisplay,
            size: info.sortableSize,
            modificationDate: modificationDate,
            isDirectory: isDirectory,
            isHidden: isHidden,
            isParentDirectoryEntry: isParentDirectoryEntry,
            iconPath: iconPath
        )
    }
}
