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
    public var onQuickSearchCycleMatch: (_ forward: Bool) -> Void
    public var onQuickSearchTabKeyDown: () -> Void
    public var onQuickSearchTabKeyUp: () -> Void
    public var onDragEnded: () -> Void
    public var onToggleExpand: (FileListRow) -> Void
    public var canRename: (FileListRow) -> Bool
    public var performRename: (_ item: FileListRow, _ newName: String, _ completion: @escaping (Bool) -> Void) -> Void
    public var onRenameEditingChanged: (_ isEditing: Bool) -> Void
    public var makeContextMenu: (_ clickedRow: FileListRow, _ selectedIDs: Set<String>) -> NSMenu?
    public var popUpContextMenu: (_ menu: NSMenu, _ event: NSEvent, _ view: NSView, _ fileURLs: [URL]) -> Void
    public var servicesRequestor: (any FileListServicesMenuRequestor)?
    public var dropDestinationPath: (FileListRow) -> String?
    /// 拖到列表空白区时的目标目录（通常为当前浏览路径）。
    public var currentDirectoryDropPath: String?
    public var canAcceptDrop: (_ destinationPath: String, _ urls: [URL]) -> Bool
    public var performDrop: (_ destinationPath: String, _ urls: [URL], _ copy: Bool) -> Void
    public var onCurrentDirectoryDropHighlightChanged: (_ isTargeted: Bool) -> Void
    public var onSpacePreview: () -> Void
    public var onQuickSearchMatchSelected: (_ rowID: String) -> Void
    
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
        onQuickSearchCycleMatch: @escaping (_ forward: Bool) -> Void = { _ in },
        onQuickSearchTabKeyDown: @escaping () -> Void = {},
        onQuickSearchTabKeyUp: @escaping () -> Void = {},
        onDragEnded: @escaping () -> Void = {},
        onToggleExpand: @escaping (FileListRow) -> Void = { _ in },
        canRename: @escaping (FileListRow) -> Bool = { _ in false },
        performRename: @escaping (_ item: FileListRow, _ newName: String, _ completion: @escaping (Bool) -> Void) -> Void = { _, _, completion in completion(false) },
        onRenameEditingChanged: @escaping (_ isEditing: Bool) -> Void = { _ in },
        makeContextMenu: @escaping (_ clickedRow: FileListRow, _ selectedIDs: Set<String>) -> NSMenu? = { _, _ in nil },
        popUpContextMenu: @escaping (_ menu: NSMenu, _ event: NSEvent, _ view: NSView, _ fileURLs: [URL]) -> Void = { menu, event, view, _ in
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        },
        servicesRequestor: (any FileListServicesMenuRequestor)? = nil,
        dropDestinationPath: @escaping (FileListRow) -> String? = { _ in nil },
        currentDirectoryDropPath: String? = nil,
        canAcceptDrop: @escaping (_ destinationPath: String, _ urls: [URL]) -> Bool = { _, _ in false },
        performDrop: @escaping (_ destinationPath: String, _ urls: [URL], _ copy: Bool) -> Void = { _, _, _ in },
        onCurrentDirectoryDropHighlightChanged: @escaping (_ isTargeted: Bool) -> Void = { _ in },
        onSpacePreview: @escaping () -> Void = {},
        onQuickSearchMatchSelected: @escaping (_ rowID: String) -> Void = { _ in }
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
        self.onQuickSearchCycleMatch = onQuickSearchCycleMatch
        self.onQuickSearchTabKeyDown = onQuickSearchTabKeyDown
        self.onQuickSearchTabKeyUp = onQuickSearchTabKeyUp
        self.onDragEnded = onDragEnded
        self.onToggleExpand = onToggleExpand
        self.canRename = canRename
        self.performRename = performRename
        self.onRenameEditingChanged = onRenameEditingChanged
        self.makeContextMenu = makeContextMenu
        self.popUpContextMenu = popUpContextMenu
        self.servicesRequestor = servicesRequestor
        self.dropDestinationPath = dropDestinationPath
        self.currentDirectoryDropPath = currentDirectoryDropPath
        self.canAcceptDrop = canAcceptDrop
        self.performDrop = performDrop
        self.onCurrentDirectoryDropHighlightChanged = onCurrentDirectoryDropHighlightChanged
        self.onSpacePreview = onSpacePreview
        self.onQuickSearchMatchSelected = onQuickSearchMatchSelected
    }
}

/// 列表与缩略图模式共用；保留 `FileListTableInteraction` 以兼容现有调用方。
public typealias FileListContentInteraction = FileListTableInteraction
