import AppKit

/// 拖放源会话、目标解析与 `performDrop` 共享逻辑（列表/缩略图共用）。
enum FileListDragDropSupport {
    enum DropHighlight: Equatable {
        case itemRow(Int)
        case currentDirectory
        case none
    }

    struct DropEvaluation: Equatable {
        let operation: NSDragOperation
        let highlight: DropHighlight
        let destinationPath: String
        let urls: [URL]
        let rowIndex: Int?
    }

    struct FileDragSession {
        let session: NSDraggingSession
        let activeDragURLs: [URL]
    }

    // MARK: - Drag source

    static func beginDraggingSession(
        on view: NSView,
        items: [NSDraggingItem],
        event: NSEvent,
        source: NSDraggingSource
    ) -> NSDraggingSession {
        FileListContentInteractionNotifier.notifyDidBegin()
        let session = view.beginDraggingSession(with: items, event: event, source: source)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = items.count > 1 ? .pile : .none
        return session
    }

    static func sourceOperationMask(for context: NSDraggingContext) -> NSDragOperation {
        if FileListDragSupport.shouldCopyFromCurrentEvent() {
            return .copy
        }
        switch context {
        case .withinApplication:
            return .move
        default:
            return .move
        }
    }

    static func makeDraggingItems(
        for row: FileListRow,
        displayRows: [FileListRow],
        selection: Set<String>,
        mousePoint: NSPoint
    ) -> [NSDraggingItem] {
        FileListInteractionCoordinator.makeDraggingItems(
            for: row,
            in: displayRows,
            selection: selection,
            mousePoint: mousePoint
        )
    }

    static func beginFileDrag(
        on view: NSView,
        row: FileListRow,
        displayRows: [FileListRow],
        selection: Set<String>,
        event: NSEvent,
        source: NSDraggingSource
    ) -> FileDragSession? {
        let mousePoint = view.convert(event.locationInWindow, from: nil)
        let draggingItems = makeDraggingItems(
            for: row,
            displayRows: displayRows,
            selection: selection,
            mousePoint: mousePoint
        )
        guard !draggingItems.isEmpty else { return nil }

        let activeDragURLs = FileListDragSupport.draggedRows(
            for: row,
            in: displayRows,
            selection: selection
        ).map { URL(fileURLWithPath: $0.iconPath) }

        let session = beginDraggingSession(
            on: view,
            items: draggingItems,
            event: event,
            source: source
        )
        return FileDragSession(session: session, activeDragURLs: activeDragURLs)
    }

    // MARK: - Drop destination

    static func resolvedURLs(
        from pasteboard: NSPasteboard,
        fallback activeDragURLs: [URL]? = nil
    ) -> [URL] {
        var urls = FileListDragSupport.fileURLs(from: pasteboard)
        if urls.isEmpty, let activeDragURLs {
            urls = activeDragURLs
        }
        return urls
    }

    static func evaluateDrop(
        displayRows: [FileListRow],
        rowIndex: Int?,
        interaction: FileListTableInteraction,
        draggingInfo: NSDraggingInfo,
        activeDragURLs: [URL]? = nil
    ) -> DropEvaluation? {
        let urls = resolvedURLs(
            from: draggingInfo.draggingPasteboard,
            fallback: activeDragURLs
        )
        let copy = FileListDragSupport.shouldCopy(from: draggingInfo)
        return evaluateDrop(
            displayRows: displayRows,
            rowIndex: rowIndex,
            interaction: interaction,
            urls: urls,
            copy: copy
        )
    }

    static func evaluateDrop(
        displayRows: [FileListRow],
        rowIndex: Int?,
        interaction: FileListTableInteraction,
        urls: [URL],
        copy: Bool
    ) -> DropEvaluation? {
        guard !urls.isEmpty else { return nil }

        guard let resolution = FileListDropTargetResolver.resolve(
            displayRows: displayRows,
            rowIndex: rowIndex,
            interaction: interaction,
            urls: urls
        ) else { return nil }

        let highlight: DropHighlight
        if let rowIndex = resolution.rowIndex {
            highlight = .itemRow(rowIndex)
        } else {
            highlight = .currentDirectory
        }

        return DropEvaluation(
            operation: copy ? .copy : .move,
            highlight: highlight,
            destinationPath: resolution.destinationPath,
            urls: urls,
            rowIndex: resolution.rowIndex
        )
    }

    static func performAcceptedDrop(
        destinationPath: String,
        urls: [URL],
        draggingInfo: NSDraggingInfo?,
        interaction: FileListTableInteraction,
        copy explicitCopy: Bool? = nil
    ) {
        let copy = explicitCopy ?? draggingInfo.map { FileListDragSupport.shouldCopy(from: $0) } ?? false
        interaction.performDrop(destinationPath, urls, copy)
    }
}
