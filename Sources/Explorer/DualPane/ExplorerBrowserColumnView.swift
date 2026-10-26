import AppKit
import FileList
import SwiftUI

/// 副栏（或可复用）浏览列：路径栏 + 文件列表。不含内容搜索 / 操作录制横幅。
struct ExplorerBrowserColumnView: View {
    @ObservedObject var pane: ExplorerPaneState
    let isActive: Bool
    let hostWindow: NSWindow?
    let showHiddenFiles: Bool
    let showPreview: Binding<Bool>
    let viewMode: FileListViewMode
    let thumbnailCellSize: CGFloat
    let useIconPreview: Bool
    let hoverPreviewEnabled: Bool
    let rightPanelPreviewVisible: Bool
    let rightPanelPreviewURL: URL?
    let directoryMetadataOverlay: DirectoryMetadataOverlay
    let contextActions: FileContextActions
    let blankMenuActions: FileListBlankMenuActions
    let pathBarContextActions: PathBarContextActions
    let onActivate: () -> Void
    let onOpenItem: (FileItem, Bool) -> Void
    let onBlankDoubleClick: () -> Void
    let onItemsChanged: () -> Void
    let onScheduleVisibleDirectorySizes: ([String]) -> Void
    let onScheduleVisibleDirectoryItemCounts: ([String]) -> Void
    let onThumbnailCellSizeChange: (CGFloat) -> Void
    let paneChromeMenu: () -> [ExplorerPaneChromeMenuItem]

    var body: some View {
        VStack(spacing: 0) {
            pathBarRow
                .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
                .overlay(alignment: .leading) {
                    if isActive {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 2)
                    }
                }

            Divider()

            fileListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .contextMenu {
            ForEach(paneChromeMenu(), id: \.id) { item in
                Button(item.title, action: item.action)
            }
        }
    }

    private var pathBarRow: some View {
        HStack(spacing: 4) {
            PathBarNavigationButtons(
                canGoBack: pane.canNavigateBack,
                canGoForward: pane.canNavigateForward,
                onBack: {
                    onActivate()
                    pane.navigateBack()
                    pane.loadItems(showHiddenFiles: showHiddenFiles)
                },
                onForward: {
                    onActivate()
                    pane.navigateForward()
                    pane.loadItems(showHiddenFiles: showHiddenFiles)
                }
            )

            PathBarView(
                path: Binding(
                    get: { pane.path },
                    set: { newPath in
                        onActivate()
                        if pane.path != newPath {
                            pane.recordNavigationIfNeeded(to: newPath)
                            pane.path = newPath
                            pane.loadItems(showHiddenFiles: showHiddenFiles)
                        }
                    }
                ),
                activeField: $pane.activeBarField,
                isTextMode: $pane.isPathBarTextMode,
                hostWindow: hostWindow,
                showHiddenFiles: showHiddenFiles,
                historyEntries: pane.pathNavigation.recentEntries(currentPath: pane.path),
                onSelectHistory: { target in
                    onActivate()
                    pane.navigateToHistoryPath(target)
                    pane.loadItems(showHiddenFiles: showHiddenFiles)
                },
                onCommitNavigation: { target in
                    onActivate()
                    pane.applyExternalNavigationTarget(target)
                    pane.loadItems(showHiddenFiles: showHiddenFiles)
                },
                contextActions: pathBarContextActions
            )
        }
        .frame(height: PanelTopBarMetrics.contentHeight)
        .padding(.trailing, 8)
        .padding(.vertical, PanelTopBarMetrics.verticalPadding)
        .onTapGesture { onActivate() }
    }

    private var fileListSection: some View {
        let isNetworkVolume = DirectorySizeVolumeFilter.isNetworkVolume(path: pane.path)
        return FileListView(
            items: pane.items,
            selection: Binding(
                get: { pane.selection },
                set: { newValue in
                    onActivate()
                    pane.selection = newValue
                }
            ),
            showPreview: showPreview,
            searchText: "",
            isContentSearchActive: false,
            quickSearchText: $pane.quickSearchText,
            isQuickSearchVisible: $pane.isQuickSearchVisible,
            isFileListRenaming: $pane.isFileListRenaming,
            focusToken: pane.fileListFocusToken,
            currentDirectoryPath: pane.path,
            canNavigateToParent: FileItem.canNavigateUp(from: pane.path),
            showHiddenFiles: showHiddenFiles,
            directoryMetadataOverlay: directoryMetadataOverlay,
            viewMode: viewMode,
            thumbnailCellSize: thumbnailCellSize,
            useIconPreview: useIconPreview && !isNetworkVolume,
            preferWorkspaceIconsInThumbnail: isNetworkVolume,
            isLoading: pane.isLoading,
            hoverPreviewEnabled: hoverPreviewEnabled,
            rightPanelPreviewVisible: rightPanelPreviewVisible,
            rightPanelPreviewURL: rightPanelPreviewURL,
            onThumbnailCellSizeChange: onThumbnailCellSizeChange,
            onItemOpen: { item, detached in
                onActivate()
                onOpenItem(item, detached)
            },
            onBlankDoubleClick: {
                onActivate()
                onBlankDoubleClick()
            },
            onItemsChanged: { _ in
                onItemsChanged()
            },
            onScheduleVisibleDirectorySizes: onScheduleVisibleDirectorySizes,
            onScheduleVisibleDirectoryItemCounts: onScheduleVisibleDirectoryItemCounts,
            contextActions: contextActions,
            blankMenuActions: blankMenuActions,
            canNavigateBack: pane.canNavigateBack,
            onNavigateBack: {
                onActivate()
                pane.navigateBack()
                pane.loadItems(showHiddenFiles: showHiddenFiles)
            },
            onNavigateToDirectory: { target in
                onActivate()
                pane.navigateToDirectory(target)
                pane.loadItems(showHiddenFiles: showHiddenFiles)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ExplorerPaneChromeMenuItem: Identifiable {
    let id: String
    let title: String
    let action: () -> Void
}
