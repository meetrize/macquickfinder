import FileList
import SwiftUI

struct ExplorerToolbarEnvironment {
    var layout: ExplorerWindowLayoutState
    var showHiddenFiles: Bool
    var sortOrder: SortOrder
    var autoCalculateDirectorySizes: Bool
    var useIconPreview: Bool
    var fileListViewMode: FileListViewMode
    var selectedItems: [FileItem]
    var deletableSelectedItems: [FileItem]
    var leftPanelMode: LeftPanelMode
    var isCustomizing: Bool
    var tabBarState: ExplorerTabBarState
    var isOperationRecording: Bool

    var toggleLeftPanelVisibility: () -> Void
    var openNewWindow: () -> Void
    var openNewTab: () -> Void
    var showAllTabs: () -> Void
    var toggleTabBar: () -> Void
    var createNewFolder: () -> Void
    var createNewFile: () -> Void
    var deleteSelectedItems: () -> Void
    var toggleHiddenFiles: () -> Void
    var setSortOrder: (SortOrder) -> Void
    var toggleAutoCalculateDirectorySizes: () -> Void
    var toggleUseIconPreview: () -> Void
    var performOpenApp: (CustomOpenAppAction) -> Void
    var editOpenApp: (CustomOpenAppAction) -> Void
    var toggleOperationRecording: () -> Void
}

enum ToolbarBuiltinDispatcher {
    @MainActor
    static func perform(_ id: ToolbarBuiltinID, environment: ExplorerToolbarEnvironment) {
        guard !environment.isCustomizing else { return }

        switch id {
        case .leftPanel:
            environment.toggleLeftPanelVisibility()
        case .newWindow:
            environment.openNewWindow()
        case .newTab:
            environment.openNewTab()
        case .showAllTabs:
            environment.showAllTabs()
        case .toggleTabBar:
            environment.toggleTabBar()
        case .preview:
            environment.layout.showPreview.toggle()
        case .snippets:
            environment.layout.showSnippets.toggle()
        case .git:
            environment.layout.toggleGitPanel()
        case .recordOperations:
            environment.toggleOperationRecording()
        case .outputPanel:
            environment.layout.toggleOutputPanel()
        case .newFolder:
            environment.createNewFolder()
        case .newFile:
            environment.createNewFile()
        case .delete:
            environment.deleteSelectedItems()
        case .toggleHiddenFiles:
            environment.toggleHiddenFiles()
        case .listView:
            environment.layout.setFileListViewMode(.list)
        case .thumbnailView:
            environment.layout.setFileListViewMode(.thumbnail)
            environment.layout.setThumbnailLayoutMode(.grid)
        case .panoramaView:
            environment.layout.setFileListViewMode(.thumbnail)
            environment.layout.setThumbnailLayoutMode(.panorama)
        case .thumbnailSizeSlider, .sortMenu, .browseSettingsMenu:
            break
        }
    }
}
