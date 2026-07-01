import FileList
import SwiftUI

@MainActor
enum ExplorerStandalonePreviewOpener {
    struct Context {
        let hostWindowID: UUID
        let directoryPath: String
        let directoryItems: [FileItem]
        let sortOrder: SortOrder
        let showHiddenFiles: Bool
        let showPreviewPanel: Bool
        let selectionContainsFile: (FileItem.ID) -> Bool
        let openWindow: OpenWindowAction
        let detachCoordinator: PreviewDetachCoordinator
    }

    static func open(file: FileItem, context: Context) {
        guard !file.isParentDirectoryEntry else { return }

        if file.isDirectory {
            return
        }

        if let existing = PreviewSessionStore.shared.detachedSession(forFileID: file.id) {
            context.detachCoordinator.focusDetachedSession(existing)
            return
        }

        if context.showPreviewPanel,
           context.selectionContainsFile(file.id),
           let inline = PreviewSessionStore.shared.existingInlineSession(
               hostWindowID: context.hostWindowID,
               fileID: file.id
           ) {
            context.detachCoordinator.detach(
                session: inline,
                directoryPath: context.directoryPath,
                directoryItems: context.directoryItems,
                sortOrder: context.sortOrder,
                showHiddenFiles: context.showHiddenFiles,
                openWindow: context.openWindow
            )
            return
        }

        let options = PreviewStandaloneOpenPreferences.options(for: file, allowsDockBack: true)
        let sessionID = PreviewDetachCoordinator.shared.openStandalonePreview(
            file: file,
            directoryPath: context.directoryPath,
            directoryItems: context.directoryItems,
            sortSnapshot: FileListPreferencesStore.shared.preferences.sort,
            options: options
        )
        context.openWindow(
            id: ExplorerWindowScene.preview,
            value: PreviewWindowValue(
                sessionID: sessionID,
                fitImageToScreen: options.fitImageToScreen,
                initialWindowSize: options.initialWindowSize
            )
        )
    }
}
