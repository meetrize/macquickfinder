import AppKit
import Foundation

/// 文件列表表格的交互回调（由 Explorer 层注入具体业务逻辑）。
public struct FileListTableInteraction {
    public var searchText: String
    public var quickSearchText: String
    public var blankMenuActions: FileListBlankMenuActions
    public var onBlankSingleClick: () -> Void
    public var onBlankDoubleClick: () -> Void
    public var canDelete: () -> Bool
    public var onDelete: () -> Void
    public var canNavigateBack: () -> Bool
    public var onNavigateBack: () -> Void
    public var onTableFocusChanged: (_ isFocused: Bool) -> Void
    public var onQuickSearchInput: (_ input: String) -> Void
    public var onQuickSearchBackspace: () -> Void
    public var onQuickSearchEscape: () -> Void
    public var onDragEnded: () -> Void
    public var makeContextMenu: (_ clickedRow: FileListRow, _ selectedIDs: Set<String>) -> NSMenu?
    public var dropDestinationPath: (FileListRow) -> String?
    public var canAcceptDrop: (_ destinationPath: String, _ urls: [URL]) -> Bool
    public var performDrop: (_ destinationPath: String, _ urls: [URL], _ copy: Bool) -> Void
    
    public init(
        searchText: String = "",
        quickSearchText: String = "",
        blankMenuActions: FileListBlankMenuActions = FileListBlankMenuActions(),
        onBlankSingleClick: @escaping () -> Void = {},
        onBlankDoubleClick: @escaping () -> Void = {},
        canDelete: @escaping () -> Bool = { false },
        onDelete: @escaping () -> Void = {},
        canNavigateBack: @escaping () -> Bool = { false },
        onNavigateBack: @escaping () -> Void = {},
        onTableFocusChanged: @escaping (_ isFocused: Bool) -> Void = { _ in },
        onQuickSearchInput: @escaping (_ input: String) -> Void = { _ in },
        onQuickSearchBackspace: @escaping () -> Void = {},
        onQuickSearchEscape: @escaping () -> Void = {},
        onDragEnded: @escaping () -> Void = {},
        makeContextMenu: @escaping (_ clickedRow: FileListRow, _ selectedIDs: Set<String>) -> NSMenu? = { _, _ in nil },
        dropDestinationPath: @escaping (FileListRow) -> String? = { _ in nil },
        canAcceptDrop: @escaping (_ destinationPath: String, _ urls: [URL]) -> Bool = { _, _ in false },
        performDrop: @escaping (_ destinationPath: String, _ urls: [URL], _ copy: Bool) -> Void = { _, _, _ in }
    ) {
        self.searchText = searchText
        self.quickSearchText = quickSearchText
        self.blankMenuActions = blankMenuActions
        self.onBlankSingleClick = onBlankSingleClick
        self.onBlankDoubleClick = onBlankDoubleClick
        self.canDelete = canDelete
        self.onDelete = onDelete
        self.canNavigateBack = canNavigateBack
        self.onNavigateBack = onNavigateBack
        self.onTableFocusChanged = onTableFocusChanged
        self.onQuickSearchInput = onQuickSearchInput
        self.onQuickSearchBackspace = onQuickSearchBackspace
        self.onQuickSearchEscape = onQuickSearchEscape
        self.onDragEnded = onDragEnded
        self.makeContextMenu = makeContextMenu
        self.dropDestinationPath = dropDestinationPath
        self.canAcceptDrop = canAcceptDrop
        self.performDrop = performDrop
    }
}
