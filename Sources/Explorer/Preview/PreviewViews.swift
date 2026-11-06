import SwiftUI
import AppKit
import FileList

struct FilePreviewView: View {
    let hostWindowID: UUID
    @Binding var showPreview: Bool
    @ObservedObject var layout: ExplorerWindowLayoutState
    @Binding var selection: Set<FileItem.ID>
    let items: [FileItem]
    let directoryPath: String
    let sortOrder: SortOrder
    let showHiddenFiles: Bool
    let autoCalculateDirectorySizes: Bool
    /// 不用 `@ObservedObject`：全局 size/count revision 会拖垮选中切换；仅文件夹预览叶子订阅。
    let metadataOverlay: DirectoryMetadataOverlay
    let onNavigate: (String) -> Void
    let onOpenItem: (FileItem) -> Void
    let onOpenTerminalAtPath: (String) -> Void
    /// 不用 `@ObservedObject`：invalidate/reveal revision 不应重绘整个预览面板。
    private let detachCoordinator = PreviewDetachCoordinator.shared
    @State private var detachPlacement: PreviewPlacement = PreviewDetachCoordinator.shared.placement
    @State private var previewSelection: Set<FileItem.ID> = []

    private var resolvedSelection: Set<FileItem.ID> {
        if previewSelection.isEmpty, !selection.isEmpty {
            return selection
        }
        return previewSelection
    }

    private var selectedItems: [FileItem] {
        FileItem.resolveSelection(ids: resolvedSelection, from: items)
    }

    private var selectedItem: FileItem? {
        selectedItems.first
    }

    var body: some View {
        Group {
            if let selectedItem {
                if detachPlacement.showsPlaceholder(forSelectedFileID: selectedItem.id),
                   case .detached(let sessionID, _) = detachPlacement,
                   let session = PreviewSessionStore.shared.session(for: sessionID) {
                    PreviewPlaceholderView(
                        fileName: session.previewContentItem?.name ?? selectedItem.name,
                        onFocus: { detachCoordinator.focusDetachedWindow() },
                        onDockBack: {
                            Task {
                                _ = await detachCoordinator.dockBack(
                                    sessionID: sessionID,
                                    currentSelectedFileID: selectedItem.id
                                )
                            }
                        }
                    )
                    .focusedValue(\.previewDetachCommands, PreviewDetachCommands(
                        canDetach: false,
                        canDock: true,
                        dockPreview: {
                            Task {
                                _ = await detachCoordinator.dockBack(
                                    sessionID: sessionID,
                                    currentSelectedFileID: selectedItem.id
                                )
                            }
                        }
                    ))
                } else {
                    FilePreviewSessionHost(
                        hostWindowID: hostWindowID,
                        selectedItem: selectedItem,
                        showPreview: $showPreview,
                        layout: layout,
                        directoryPath: directoryPath,
                        directoryItems: items,
                        sortOrder: sortOrder,
                        showHiddenFiles: showHiddenFiles,
                        autoCalculateDirectorySizes: autoCalculateDirectorySizes,
                        metadataOverlay: metadataOverlay,
                        onNavigate: onNavigate,
                        onOpenItem: onOpenItem,
                        onOpenTerminalAtPath: onOpenTerminalAtPath,
                        detachCoordinator: detachCoordinator
                    )
                    .id(selectedItem.id)
                }
            } else {
                FilePreviewEmptyChrome(showPreview: $showPreview, layout: layout)
            }
        }
        .onReceive(detachCoordinator.$placement) { detachPlacement = $0 }
        .onAppear {
            detachPlacement = detachCoordinator.placement
            previewSelection = selection
        }
        .onChange(of: directoryPath) { _ in
            // 换目录时同步清空，避免「空 selection 保留预览」把上个目录文件粘住。
            previewSelection = selection
        }
        .onChange(of: selection) { newSelection in
            handleSelectionChange(to: newSelection)
        }
    }

    private func handleSelectionChange(to newSelection: Set<FileItem.ID>) {
        guard newSelection != previewSelection else { return }
        // 失去 key 后对账会 `loadItems` 并短暂 `selection.removeAll()`；若同步清空
        // previewSelection，内联 PreviewSession 会 onDisappear 被拆掉，预览变空白。
        // 内容搜索选中子目录文件时，旧逻辑也无法从当前 listing 恢复选中。
        if newSelection.isEmpty {
            return
        }
        let previousSelection = previewSelection
        // 无未保存编辑时同步切换，保证内容搜索 reveal 通知打到正确预览宿主。
        if PreviewSessionStore.shared.inlineSessionWithUnsavedTextEdits(hostWindowID: hostWindowID) == nil {
            previewSelection = newSelection
            return
        }
        Task { @MainActor in
            if let session = PreviewSessionStore.shared.inlineSessionWithUnsavedTextEdits(
                hostWindowID: hostWindowID
            ) {
                guard await session.confirmDiscardTextEditsIfNeeded() else {
                    selection = previousSelection
                    return
                }
            }
            previewSelection = newSelection
        }
    }
}

private struct FilePreviewEmptyChrome: View {
    @Binding var showPreview: Bool
    @ObservedObject var layout: ExplorerWindowLayoutState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    layout.isPreviewContentCollapsed.toggle()
                } label: {
                    Image(systemName: layout.isPreviewContentCollapsed ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .instantHoverTooltip(layout.isPreviewContentCollapsed ? L10n.Preview.expand : L10n.Preview.collapse)

                Text(L10n.Preview.title)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 0, maxWidth: 72, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(-1)

                Spacer(minLength: 0)

                Button {
                    showPreview = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .instantHoverTooltip(L10n.Preview.close)
                .fixedSize()
                .layoutPriority(2)
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .padding(.horizontal, 10)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)

            Divider()
            if !layout.isPreviewContentCollapsed {
                Text(L10n.Preview.emptyState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
