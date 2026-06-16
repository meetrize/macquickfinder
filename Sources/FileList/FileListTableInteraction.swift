import AppKit
import Foundation

/// 文件列表表格的交互回调（由 Explorer 层注入具体业务逻辑）。
public struct FileListTableInteraction {
    public var searchText: String
    public var blankMenuActions: FileListBlankMenuActions
    public var canDelete: () -> Bool
    public var onDelete: () -> Void
    public var onDragEnded: () -> Void
    public var makeContextMenu: (_ clickedRow: FileListRow, _ selectedIDs: Set<String>) -> NSMenu?
    public var dropDestinationPath: (FileListRow) -> String?
    public var canAcceptDrop: (_ destinationPath: String, _ urls: [URL]) -> Bool
    public var performDrop: (_ destinationPath: String, _ urls: [URL], _ copy: Bool) -> Void
    
    public init(
        searchText: String = "",
        blankMenuActions: FileListBlankMenuActions = FileListBlankMenuActions(),
        canDelete: @escaping () -> Bool = { false },
        onDelete: @escaping () -> Void = {},
        onDragEnded: @escaping () -> Void = {},
        makeContextMenu: @escaping (_ clickedRow: FileListRow, _ selectedIDs: Set<String>) -> NSMenu? = { _, _ in nil },
        dropDestinationPath: @escaping (FileListRow) -> String? = { _ in nil },
        canAcceptDrop: @escaping (_ destinationPath: String, _ urls: [URL]) -> Bool = { _, _ in false },
        performDrop: @escaping (_ destinationPath: String, _ urls: [URL], _ copy: Bool) -> Void = { _, _, _ in }
    ) {
        self.searchText = searchText
        self.blankMenuActions = blankMenuActions
        self.canDelete = canDelete
        self.onDelete = onDelete
        self.onDragEnded = onDragEnded
        self.makeContextMenu = makeContextMenu
        self.dropDestinationPath = dropDestinationPath
        self.canAcceptDrop = canAcceptDrop
        self.performDrop = performDrop
    }
}
