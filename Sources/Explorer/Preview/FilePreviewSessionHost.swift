import SwiftUI
import AppKit
import FileList

struct FilePreviewSessionHost: View {
    let hostWindowID: UUID
    let selectedItem: FileItem
    @Binding var showPreview: Bool
    @ObservedObject var layout: ExplorerWindowLayoutState
    let directoryPath: String
    let directoryItems: [FileItem]
    let sortOrder: SortOrder
    let showHiddenFiles: Bool
    let autoCalculateDirectorySizes: Bool
    @ObservedObject var metadataOverlay: DirectoryMetadataOverlay
    let onNavigate: (String) -> Void
    let onOpenItem: (FileItem) -> Void
    let onOpenTerminalAtPath: (String) -> Void
    @ObservedObject var detachCoordinator: PreviewDetachCoordinator

    @Environment(\.openWindow) private var openWindow
    @StateObject private var session: PreviewSession

    init(
        hostWindowID: UUID,
        selectedItem: FileItem,
        showPreview: Binding<Bool>,
        layout: ExplorerWindowLayoutState,
        directoryPath: String,
        directoryItems: [FileItem],
        sortOrder: SortOrder,
        showHiddenFiles: Bool,
        autoCalculateDirectorySizes: Bool,
        metadataOverlay: DirectoryMetadataOverlay,
        onNavigate: @escaping (String) -> Void,
        onOpenItem: @escaping (FileItem) -> Void,
        onOpenTerminalAtPath: @escaping (String) -> Void,
        detachCoordinator: PreviewDetachCoordinator
    ) {
        self.hostWindowID = hostWindowID
        self.selectedItem = selectedItem
        _showPreview = showPreview
        self.layout = layout
        self.directoryPath = directoryPath
        self.directoryItems = directoryItems
        self.sortOrder = sortOrder
        self.showHiddenFiles = showHiddenFiles
        self.autoCalculateDirectorySizes = autoCalculateDirectorySizes
        self.metadataOverlay = metadataOverlay
        self.onNavigate = onNavigate
        self.onOpenItem = onOpenItem
        self.onOpenTerminalAtPath = onOpenTerminalAtPath
        self.detachCoordinator = detachCoordinator
        let session = PreviewSessionStore.shared.existingInlineSession(
            hostWindowID: hostWindowID,
            fileID: selectedItem.id
        ) ?? PreviewSession(hostWindowID: hostWindowID, file: selectedItem)
        _session = StateObject(wrappedValue: session)
        PreviewSessionStore.shared.register(session)
    }

    private var canDetachPreview: Bool {
        PreviewCapability.canDetach(session: session, selectedItem: selectedItem)
    }

    private var previewToolbarTitleMaxWidth: CGFloat {
        session.isShowingFolderChildPreview ? 56 : 72
    }

    var body: some View {
        VStack(spacing: 0) {
            PreviewChromeView(
                session: session,
                title: session.previewContentItem?.name ?? selectedItem.name,
                titleMaxWidth: previewToolbarTitleMaxWidth,
                isContentCollapsed: layout.isPreviewContentCollapsed,
                placement: .inlinePanel,
                actions: PreviewChromeActions(
                    onToggleCollapse: { layout.isPreviewContentCollapsed.toggle() },
                    onBackFromFolderChild: { session.folderInlineChild = nil },
                    onDetach: canDetachPreview ? { detachPreview() } : nil,
                    onClose: { showPreview = false }
                )
            )

            if !layout.isPreviewContentCollapsed {
                Divider()
                inlinePreviewContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .previewSessionInteractions(session)
        .focusedValue(\.previewDetachCommands, PreviewDetachCommands(
            canDetach: canDetachPreview,
            canDock: {
                if case .detached(let sessionID, _) = detachCoordinator.placement {
                    return sessionID == session.id
                }
                return false
            }(),
            detachPreview: detachPreview,
            dockPreview: dockPreview
        ))
        .onDisappear {
            guard !session.location.isDetached else { return }
            PreviewSessionStore.shared.remove(session.id)
        }
    }

    @ViewBuilder
    private var inlinePreviewContent: some View {
        if let folderInlineChild = session.folderInlineChild {
            FileContentView(session: session)
                .id(folderInlineChild.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedItem.isDirectory {
            FolderPreviewView(
                folder: selectedItem,
                showHiddenFiles: showHiddenFiles,
                autoCalculateDirectorySizes: autoCalculateDirectorySizes,
                metadataOverlay: metadataOverlay,
                showContentsList: true,
                onNavigate: onNavigate,
                onOpenFolder: { onOpenItem(selectedItem) },
                onOpenTerminal: { onOpenTerminalAtPath(selectedItem.id) },
                onPreviewChild: { session.folderInlineChild = $0 },
                onOpenChild: onOpenItem
            )
            .id(selectedItem.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            FileContentView(session: session)
                .id(selectedItem.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detachPreview() {
        detachCoordinator.detach(
            session: session,
            directoryPath: directoryPath,
            directoryItems: directoryItems,
            sortOrder: sortOrder,
            showHiddenFiles: showHiddenFiles,
            openWindow: openWindow
        )
    }

    private func dockPreview() {
        Task {
            _ = await detachCoordinator.dockBack(
                sessionID: session.id,
                currentSelectedFileID: selectedItem.id
            )
        }
    }
}
