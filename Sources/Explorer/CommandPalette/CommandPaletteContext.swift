import FileList
import Foundation

@MainActor
struct CommandPaletteContext {
    var currentPath: String
    var selectedItems: [FileItem]
    var deletableSelectedItems: [FileItem]
    var layout: ExplorerWindowLayoutState
    var toolbarEnvironment: ExplorerToolbarEnvironment
    var fileHandlers: FileCommandHandlers
    var fileActions: FileContextActions
    var blankMenuActions: FileListBlankMenuActions
    var previewDetach: PreviewDetachCommands?
    var previewBrowse: PreviewBrowseCommands?
    var tabBarState: ExplorerTabBarState
    var showHiddenFiles: Bool

    var canNavigateBack: Bool
    var canNavigateForward: Bool
    var canNavigateUp: Bool

    var focusSearch: () -> Void
    var focusFindInFolder: () -> Void
    var navigateBack: () -> Void
    var navigateForward: () -> Void
    var navigateUp: () -> Void
    var presentConnectServer: () -> Void
    var openSettings: () -> Void
    var openHelp: () -> Void
    var customizeToolbar: () -> Void
    var toggleCommandPalette: () -> Void
    var importSnippets: () -> Void
    var exportSnippets: () -> Void
    var focusOutputCommand: () -> Void
}
