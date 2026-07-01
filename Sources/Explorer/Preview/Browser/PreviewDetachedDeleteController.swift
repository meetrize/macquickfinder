import AppKit
import FileList

@MainActor
enum PreviewDetachedDeleteController {
    static func handleDeleteKey(
        event: NSEvent,
        session: PreviewSession,
        onNoItemsRemaining: @escaping () -> Void
    ) -> Bool {
        guard event.keyCode == 51 || event.keyCode == 117 else { return false }
        guard !event.modifierFlags.contains(.command) else { return false }
        guard !isTextInputActive() else { return false }

        let item = session.browseTarget
        guard !item.isDirectory else { return false }
        guard !TrashLoader.isTrashPath(item.url.path) else { return false }

        deleteCurrentPreviewFile(in: session, onNoItemsRemaining: onNoItemsRemaining)
        return true
    }

    static func deleteCurrentPreviewFile(
        in session: PreviewSession,
        onNoItemsRemaining: @escaping () -> Void
    ) {
        let item = session.browseTarget
        FileOperations.delete([item]) {
            handleDeleted(item: item, in: session, onNoItemsRemaining: onNoItemsRemaining)
        }
    }

    private static func handleDeleted(
        item: FileItem,
        in session: PreviewSession,
        onNoItemsRemaining: () -> Void
    ) {
        if let context = session.browseContext {
            context.removeItem(withID: item.id)
            if context.orderedItems.isEmpty {
                onNoItemsRemaining()
                return
            }

            PreviewDetachCoordinator.shared.updateDetachedFileID(
                sessionID: session.id,
                fileID: context.currentItem.id
            )
            session.cancelLoad()
            session.resetControls()
            session.scheduleBrowseContentPrefetch(
                settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
            )
            return
        }

        onNoItemsRemaining()
    }

    private static func isTextInputActive() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if responder is NSTextView { return true }
        if responder is NSTextField { return true }
        return false
    }
}
