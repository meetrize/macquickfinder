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
    @ObservedObject var metadataOverlay: DirectoryMetadataOverlay
    let onNavigate: (String) -> Void
    let onOpenItem: (FileItem) -> Void
    let onOpenTerminalAtPath: (String) -> Void
    @ObservedObject private var detachCoordinator = PreviewDetachCoordinator.shared
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
                if detachCoordinator.placement.showsPlaceholder(forSelectedFileID: selectedItem.id),
                   case .detached(let sessionID, _) = detachCoordinator.placement,
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
        .onAppear {
            previewSelection = selection
        }
        .onChange(of: selection) { newSelection in
            handleSelectionChange(to: newSelection)
        }
    }

    private func handleSelectionChange(to newSelection: Set<FileItem.ID>) {
        guard newSelection != previewSelection else { return }
        let previousSelection = previewSelection
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

            if !layout.isPreviewContentCollapsed {
                Divider()
                Text(L10n.Preview.emptyState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
