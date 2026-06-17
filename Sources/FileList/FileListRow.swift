import Foundation

/// 文件列表行展示模型（与 Explorer 的 `FileItem` 解耦，供 NSTableView 使用）。
public struct FileListRow: Equatable, Sendable, Identifiable {
    /// 用于识别「..」行，与 Explorer 的 `FileItem.parentDirectoryID` 保持一致。
    public static let parentDirectoryID = "__parent_directory__"
    
    public let id: String
    public let name: String
    public let fileType: String
    public let sizeDisplay: String
    /// 文件夹子项数量角标文案（仅缩略图模式目录格使用）。
    public let childCountDisplay: String?
    public let dateDisplay: String
    public let size: Int64
    public let modificationDate: Date
    public let isDirectory: Bool
    public let isHidden: Bool
    public let isParentDirectoryEntry: Bool
    /// 用于 `NSWorkspace` 取图标的路径。
    public let iconPath: String
    /// 树形层级（根节点为 0）。
    public let depth: Int
    /// 树形父节点 id（根节点为 nil）。
    public let parentID: String?
    /// 是否显示可展开箭头。
    public let isExpandable: Bool
    /// 当前是否已展开。
    public let isExpanded: Bool
    /// 当前是否处于展开加载中。
    public let isExpanding: Bool
    /// 展开失败时的简短错误提示。
    public let expandErrorMessage: String?
    
    public init(
        id: String,
        name: String,
        fileType: String,
        sizeDisplay: String,
        childCountDisplay: String? = nil,
        dateDisplay: String,
        size: Int64,
        modificationDate: Date,
        isDirectory: Bool,
        isHidden: Bool,
        isParentDirectoryEntry: Bool,
        iconPath: String,
        depth: Int = 0,
        parentID: String? = nil,
        isExpandable: Bool = false,
        isExpanded: Bool = false,
        isExpanding: Bool = false,
        expandErrorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.fileType = fileType
        self.sizeDisplay = sizeDisplay
        self.childCountDisplay = childCountDisplay
        self.dateDisplay = dateDisplay
        self.size = size
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
        self.isHidden = isHidden
        self.isParentDirectoryEntry = isParentDirectoryEntry
        self.iconPath = iconPath
        self.depth = max(0, depth)
        self.parentID = parentID
        self.isExpandable = isExpandable
        self.isExpanded = isExpanded
        self.isExpanding = isExpanding
        self.expandErrorMessage = expandErrorMessage
    }
    
    /// 除 Size 列展示字段外，是否与另一行相同（用于判断仅需刷新大小列）。
    public func hasSameStaticContent(as other: FileListRow) -> Bool {
        id == other.id
            && name == other.name
            && fileType == other.fileType
            && childCountDisplay == other.childCountDisplay
            && dateDisplay == other.dateDisplay
            && modificationDate == other.modificationDate
            && isDirectory == other.isDirectory
            && isHidden == other.isHidden
            && isParentDirectoryEntry == other.isParentDirectoryEntry
            && iconPath == other.iconPath
            && depth == other.depth
            && parentID == other.parentID
            && isExpandable == other.isExpandable
            && isExpanded == other.isExpanded
            && isExpanding == other.isExpanding
            && expandErrorMessage == other.expandErrorMessage
    }
    
    func withDirectorySizeDisplay(_ info: DirectorySizeDisplayInfo) -> FileListRow {
        guard isDirectory, !isParentDirectoryEntry else { return self }
        return FileListRow(
            id: id,
            name: name,
            fileType: fileType,
            sizeDisplay: info.text,
            childCountDisplay: childCountDisplay,
            dateDisplay: dateDisplay,
            size: info.sortableSize,
            modificationDate: modificationDate,
            isDirectory: isDirectory,
            isHidden: isHidden,
            isParentDirectoryEntry: isParentDirectoryEntry,
            iconPath: iconPath,
            depth: depth,
            parentID: parentID,
            isExpandable: isExpandable,
            isExpanded: isExpanded,
            isExpanding: isExpanding,
            expandErrorMessage: expandErrorMessage
        )
    }
    
    func withChildCountDisplay(_ info: DirectoryItemCountDisplayInfo) -> FileListRow {
        guard isDirectory, !isParentDirectoryEntry else { return self }
        guard info != .unknown else {
            guard childCountDisplay != nil else { return self }
            return FileListRow(
                id: id,
                name: name,
                fileType: fileType,
                sizeDisplay: sizeDisplay,
                childCountDisplay: nil,
                dateDisplay: dateDisplay,
                size: size,
                modificationDate: modificationDate,
                isDirectory: isDirectory,
                isHidden: isHidden,
                isParentDirectoryEntry: isParentDirectoryEntry,
                iconPath: iconPath,
                depth: depth,
                parentID: parentID,
                isExpandable: isExpandable,
                isExpanded: isExpanded,
                isExpanding: isExpanding,
                expandErrorMessage: expandErrorMessage
            )
        }
        guard childCountDisplay != info.text else { return self }
        return FileListRow(
            id: id,
            name: name,
            fileType: fileType,
            sizeDisplay: sizeDisplay,
            childCountDisplay: info.text,
            dateDisplay: dateDisplay,
            size: size,
            modificationDate: modificationDate,
            isDirectory: isDirectory,
            isHidden: isHidden,
            isParentDirectoryEntry: isParentDirectoryEntry,
            iconPath: iconPath,
            depth: depth,
            parentID: parentID,
            isExpandable: isExpandable,
            isExpanded: isExpanded,
            isExpanding: isExpanding,
            expandErrorMessage: expandErrorMessage
        )
    }
}
