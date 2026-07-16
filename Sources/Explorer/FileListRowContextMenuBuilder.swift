import AppKit
import CoreServices
import FileList

@MainActor
enum FileListRowContextMenuBuilder {
    @MainActor
    static func makeMenu(
        clickedRow: FileListRow,
        selectedItems: [FileItem],
        currentDirectoryPath: String,
        showHiddenFiles: Bool,
        actions: FileContextActions
    ) -> NSMenu? {
        let menu = NSMenu()
        let fileSelection = selectedItems.filter { !$0.isParentDirectoryEntry }
        let inTrash = actions.isInTrash
        
        if selectedItems.count == 1,
           let item = selectedItems.first,
           item.isParentDirectoryEntry {
            appendRefreshIfNeeded(to: menu, actions: actions)
            menu.addItem(menuItem(title: L10n.Action.open) { actions.open(item) })
            menu.addItem(menuItem(title: L10n.Action.openInNewWindow) { actions.openInNewWindow(item) })
            SnippetsContextMenuBuilder.appendSnippetsMenu(
                to: menu,
                cwd: currentDirectoryPath,
                selectedItems: selectedItems,
                showHiddenFiles: showHiddenFiles
            )
            return menu.items.isEmpty ? nil : menu
        }
        
        if selectedItems.isEmpty {
            return nil
        }
        
        if inTrash && !selectedItems.isEmpty {
            if selectedItems.count == 1, let item = selectedItems.first {
                menu.addItem(menuItem(title: L10n.Action.open) { actions.open(item) })
            } else {
                menu.addItem(menuItem(title: L10n.Action.open) {
                    for item in selectedItems { actions.open(item) }
                })
            }
            menu.addItem(.separator())
            menu.addItem(menuItem(title: L10n.Action.putBack) { actions.putBack(selectedItems) })
            menu.addItem(menuItem(title: L10n.Action.deleteImmediately, destructive: true) {
                actions.deleteImmediately(selectedItems)
            })
            menu.addItem(.separator())
            menu.addItem(menuItem(title: L10n.Action.emptyTrash, destructive: true) { actions.emptyTrash() })
            return menu
        }
        
        guard !fileSelection.isEmpty else { return nil }
        
        appendRefreshIfNeeded(to: menu, actions: actions)
        
        let destination = FileOperations.pasteDestination(
            selectedItems: fileSelection,
            currentDirectoryPath: currentDirectoryPath
        )
        let showPaste = actions.canPaste(destination)
        
        if showPaste {
            menu.addItem(menuItem(title: L10n.Action.paste) { actions.paste(destination) })
            menu.addItem(.separator())
        }
        
        if fileSelection.count == 1, let item = fileSelection.first {
            menu.addItem(menuItem(title: L10n.Action.open) { actions.open(item) })
            if actions.canOpenInDetachedPreview(item) {
                menu.addItem(menuItem(
                    title: L10n.Action.openInDetachedPreview,
                    keyEquivalent: "p",
                    modifierMask: [.command, .option]
                ) {
                    actions.openInDetachedPreview(item)
                })
            }
            if isNavigableFolder(item) {
                menu.addItem(menuItem(title: L10n.Action.openInNewWindow) { actions.openInNewWindow(item) })
            }
            if !item.isDirectory {
                menu.addItem(openWithMenuItem(primaryItem: item, selectedItems: fileSelection, actions: actions))
            }
            if item.isDirectory, !actions.isFavorited(item) {
                menu.addItem(menuItem(title: L10n.Action.addFavorite) { actions.addToFavorites(item) })
            }
            menu.addItem(.separator())
        } else {
            menu.addItem(menuItem(title: L10n.Action.open) {
                for item in fileSelection { actions.open(item) }
            })
            menu.addItem(.separator())
        }
        
        menu.addItem(menuItem(title: L10n.Action.cut) { actions.cut(fileSelection) })
        menu.addItem(menuItem(title: L10n.Action.copy) { actions.copy(fileSelection) })
        menu.addItem(.separator())
        
        if fileSelection.count == 1, let item = fileSelection.first {
            menu.addItem(menuItem(title: L10n.Action.copyFilename) { actions.copyFilename(item) })
        }
        menu.addItem(menuItem(title: L10n.Action.copyPaths) { actions.copyPaths(fileSelection) })

        let showCompress = ArchiveOperations.canCompress(fileSelection, inTrash: inTrash)
        let showExtract = ArchiveOperations.canExtract(fileSelection, inTrash: inTrash)
        if showCompress {
            let title: String
            if fileSelection.count == 1, let item = fileSelection.first {
                title = L10n.Action.compressOne(item.name)
            } else {
                title = L10n.Action.compressMany(fileSelection.count)
            }
            menu.addItem(menuItem(title: title) { actions.compress(fileSelection) })
        }
        if showExtract {
            menu.addItem(makeExtractSubmenu(fileSelection: fileSelection, actions: actions))
        }
        if showCompress || showExtract {
            menu.addItem(.separator())
        }

        menu.addItem(menuItem(title: L10n.Action.delete, destructive: true) { actions.delete(fileSelection) })
        
        if fileSelection.count == 1, let item = fileSelection.first {
            menu.addItem(menuItem(title: L10n.Action.rename) { actions.rename(item) })
            menu.addItem(.separator())
            menu.addItem(menuItem(title: L10n.Action.openTerminalHere) { actions.openTerminal(item) })
        }

        SnippetsContextMenuBuilder.appendSnippetsMenu(
            to: menu,
            cwd: currentDirectoryPath,
            selectedItems: selectedItems,
            showHiddenFiles: showHiddenFiles
        )

        let fileURLs = fileSelection.map(\.url)
        FileServicesMenuSupport.appendToMenu(menu, fileURLs: fileURLs)
        
        menu.addItem(menuItem(title: L10n.Action.showInfo) { actions.showInfo(fileSelection) })
        menu.addItem(menuItem(
            title: L10n.Action.showFinderInfo,
            keyEquivalent: "i",
            modifierMask: [.command]
        ) {
            actions.showFinderInfo(fileSelection)
        })
        return menu
    }

    private static func makeExtractSubmenu(
        fileSelection: [FileItem],
        actions: FileContextActions
    ) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.Action.extract, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(menuItem(title: L10n.Action.extractHere) { actions.extractHere(fileSelection) })
        submenu.addItem(menuItem(title: L10n.Action.extractTo) { actions.extractTo(fileSelection) })
        submenu.addItem(menuItem(title: L10n.Action.extractDownloads) { actions.extractToDownloads(fileSelection) })
        item.submenu = submenu
        return item
    }

    private static func appendRefreshIfNeeded(to menu: NSMenu, actions: FileContextActions) {
        guard actions.showRefresh else { return }
        menu.addItem(menuItem(title: L10n.Action.refresh) { actions.refresh() })
        menu.addItem(.separator())
    }

    private static func isNavigableFolder(_ item: FileItem) -> Bool {
        if item.isParentDirectoryEntry { return true }
        return item.isDirectory && item.url.pathExtension.lowercased() != "app"
    }

    private static func openWithMenuItem(
        primaryItem: FileItem,
        selectedItems: [FileItem],
        actions: FileContextActions
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: L10n.Action.openWith, action: nil, keyEquivalent: "")
        menuItem.submenu = makeOpenWithSubmenu(primaryItem: primaryItem, selectedItems: selectedItems, actions: actions)
        return menuItem
    }

    private static func makeOpenWithSubmenu(
        primaryItem: FileItem,
        selectedItems: [FileItem],
        actions: FileContextActions
    ) -> NSMenu {
        let openableItems = selectedItems.filter { !$0.isDirectory }
        return OpenWithMenuBuilder.makeMenu(
            fileURLs: openableItems.map(\.url),
            primaryFileURL: primaryItem.url,
            onOpenWithApplication: { appURL in
                actions.openWithApplication(openableItems, appURL)
            },
            onChooseOther: {
                actions.openWith(primaryItem)
            }
        )
    }
    
    private static func menuItem(
        title: String,
        destructive: Bool = false,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = [],
        action: @escaping () -> Void
    ) -> NSMenuItem {
        CallbackMenuItem(
            title: title,
            isDestructive: destructive,
            keyEquivalent: keyEquivalent,
            modifierMask: modifierMask,
            action: action
        )
    }
}

private final class CallbackMenuItem: NSMenuItem {
    private let callback: () -> Void

    init(
        title: String,
        isDestructive: Bool,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = [],
        action: @escaping () -> Void
    ) {
        callback = action
        super.init(title: title, action: #selector(performAction), keyEquivalent: keyEquivalent)
        target = self
        if !keyEquivalent.isEmpty {
            keyEquivalentModifierMask = modifierMask
        }
        if isDestructive {
            attributedTitle = NSAttributedString(
                string: title,
                attributes: [.foregroundColor: NSColor.systemRed]
            )
        }
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func performAction() {
        callback()
    }
}
