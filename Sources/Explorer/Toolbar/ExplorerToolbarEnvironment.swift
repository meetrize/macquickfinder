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

    var toggleLeftPanelVisibility: () -> Void
    var createNewFolder: () -> Void
    var deleteSelectedItems: () -> Void
    var toggleHiddenFiles: () -> Void
    var setSortOrder: (SortOrder) -> Void
    var toggleAutoCalculateDirectorySizes: () -> Void
    var toggleUseIconPreview: () -> Void
    var performOpenApp: (CustomOpenAppAction) -> Void
    var editOpenApp: (CustomOpenAppAction) -> Void
}

enum ToolbarBuiltinDispatcher {
    @MainActor
    static func perform(_ id: ToolbarBuiltinID, environment: ExplorerToolbarEnvironment) {
        guard !environment.isCustomizing else { return }

        switch id {
        case .leftPanel:
            environment.toggleLeftPanelVisibility()
        case .preview:
            environment.layout.showPreview.toggle()
        case .snippets:
            environment.layout.showSnippets.toggle()
        case .outputPanel:
            environment.layout.toggleOutputPanel()
        case .newFolder:
            environment.createNewFolder()
        case .delete:
            environment.deleteSelectedItems()
        case .toggleHiddenFiles:
            environment.toggleHiddenFiles()
        case .listView:
            environment.layout.setFileListViewMode(.list)
        case .thumbnailView:
            environment.layout.setFileListViewMode(.thumbnail)
        case .thumbnailSizeSlider, .sortMenu, .browseSettingsMenu:
            break
        }
    }
}
