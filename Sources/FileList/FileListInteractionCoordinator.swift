import AppKit
import Foundation

/// 列表与缩略图共用的交互辅助逻辑（键盘、框选、拖放项构建）。
enum FileListInteractionCoordinator {
    static let dragThreshold: CGFloat = 4

    static func quickSearchInputCharacter(from event: NSEvent) -> String? {
        guard let input = event.charactersIgnoringModifiers, input.count == 1,
              let scalar = input.unicodeScalars.first
        else { return nil }

        if CharacterSet.whitespacesAndNewlines.contains(scalar) { return nil }
        if CharacterSet.controlCharacters.contains(scalar) { return nil }
        if (0xF700...0xF8FF).contains(scalar.value) { return nil }

        if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) {
            return input
        }
        if input == "." {
            return input
        }
        return nil
    }

    static func rowsInVerticalRange(
        minY: CGFloat,
        maxY: CGFloat,
        in tableView: NSTableView
    ) -> IndexSet {
        let lower = min(minY, maxY)
        let upper = max(minY, maxY)
        var rows = IndexSet()
        for row in 0..<tableView.numberOfRows {
            let rowRect = tableView.rect(ofRow: row)
            if rowRect.maxY >= lower && rowRect.minY <= upper {
                rows.insert(row)
            }
        }
        return rows
    }

    /// ESC / 快速搜索退格与输入 / 无选中时 Backspace 后退。
    static func handleQuickSearchKeys(
        event: NSEvent,
        interaction: FileListTableInteraction,
        effectiveSelectionIDs: () -> Set<String>
    ) -> Bool {
        let flags = event.modifierFlags
        guard !flags.contains(.command), !flags.contains(.control), !flags.contains(.option) else {
            return false
        }

        if event.keyCode == 53 {
            interaction.onQuickSearchEscape()
            return true
        }

        if event.keyCode == 48 {
            guard !interaction.quickSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            interaction.onQuickSearchTabKeyDown()
            interaction.onQuickSearchCycleMatch(!flags.contains(.shift))
            return true
        }

        if event.keyCode == 51 || event.keyCode == 117 {
            if !interaction.quickSearchText.isEmpty {
                interaction.onQuickSearchBackspace()
                return true
            }
            if event.keyCode == 51,
               effectiveSelectionIDs().isEmpty,
               interaction.canNavigateBack() {
                interaction.onNavigateBack()
                return true
            }
        }

        if let input = quickSearchInputCharacter(from: event) {
            interaction.onQuickSearchInput(input)
            return true
        }

        return false
    }

    static func handleQuickSearchKeyUp(event: NSEvent, interaction: FileListTableInteraction) -> Bool {
        guard event.keyCode == 48 else { return false }
        guard !interaction.quickSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        interaction.onQuickSearchTabKeyUp()
        return true
    }

    static func nextQuickSearchMatchIndex(
        in matches: [Int],
        from currentRow: Int?,
        forward: Bool
    ) -> Int? {
        guard !matches.isEmpty else { return nil }
        guard matches.count > 1 else { return matches[0] }

        if let currentRow, let currentIndex = matches.firstIndex(of: currentRow) {
            let nextIndex = forward
                ? (currentIndex + 1) % matches.count
                : (currentIndex + matches.count - 1) % matches.count
            return matches[nextIndex]
        }
        return forward ? matches[0] : matches[matches.count - 1]
    }

    static func handleDeleteKey(event: NSEvent, interaction: FileListTableInteraction) -> Bool {
        guard event.keyCode == 51 || event.keyCode == 117 else { return false }
        guard !event.modifierFlags.contains(.command) else { return false }
        guard interaction.canDelete() else { return false }
        interaction.onDelete()
        return true
    }

    static func showBlankContextMenu(
        for event: NSEvent,
        on view: NSView,
        actions: FileListBlankMenuActions
    ) {
        guard actions.isEnabled else { return }
        let controller = FileListBlankMenuController(actions: actions)
        controller.popUp(with: event, for: view)
    }

    static func makeDraggingItems(
        for row: FileListRow,
        in displayRows: [FileListRow],
        selection: Set<String>,
        mousePoint: NSPoint
    ) -> [NSDraggingItem] {
        let dragged = FileListDragSupport.draggedRows(
            for: row,
            in: displayRows,
            selection: selection
        )
        guard !dragged.isEmpty else { return [] }

        var draggingItems: [NSDraggingItem] = []
        for (index, draggedRow) in dragged.enumerated() {
            let showLabel = dragged.count == 1 || draggedRow.id == row.id
            let ghost = FileListDragSupport.makeDragGhost(
                for: draggedRow.iconPath,
                name: draggedRow.name,
                showLabel: showLabel
            )
            let frame = FileListDragSupport.draggingFrame(
                at: mousePoint,
                ghostSize: ghost.size,
                index: index,
                showLabel: showLabel
            )
            let url = URL(fileURLWithPath: draggedRow.iconPath) as NSURL
            let draggingItem = NSDraggingItem(pasteboardWriter: url)
            draggingItem.setDraggingFrame(frame, contents: ghost.image)
            draggingItems.append(draggingItem)
        }
        return draggingItems
    }

    static func tableEffectiveSelectionIDs(
        selectionGet: (() -> Set<String>)?,
        tableSelectedRowIDs: Set<String>
    ) -> Set<String> {
        var ids = selectionGet?() ?? []
        ids.remove(FileListRow.parentDirectoryID)
        ids.formUnion(tableSelectedRowIDs.filter { $0 != FileListRow.parentDirectoryID })
        return ids
    }

    static func collectionEffectiveSelectionIDs(
        selectionGet: (() -> Set<String>)?,
        collectionSelectedIDs: Set<String>
    ) -> Set<String> {
        var ids = selectionGet?() ?? []
        ids.remove(FileListRow.parentDirectoryID)
        ids.formUnion(collectionSelectedIDs.filter { $0 != FileListRow.parentDirectoryID })
        return ids
    }
}
