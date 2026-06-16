import AppKit
import FileList

enum FileListRowContextMenuBuilder {
    static func makeMenu(
        clickedRow: FileListRow,
        selectedItems: [FileItem],
        currentDirectoryPath: String,
        actions: FileContextActions
    ) -> NSMenu? {
        let menu = NSMenu()
        let fileSelection = selectedItems.filter { !$0.isParentDirectoryEntry }
        let inTrash = actions.isInTrash
        
        if selectedItems.count == 1,
           let item = selectedItems.first,
           item.isParentDirectoryEntry {
            menu.addItem(menuItem(title: "打开") { actions.open(item) })
            return menu.items.isEmpty ? nil : menu
        }
        
        if selectedItems.isEmpty {
            return nil
        }
        
        if inTrash && !selectedItems.isEmpty {
            if selectedItems.count == 1, let item = selectedItems.first {
                menu.addItem(menuItem(title: "打开") { actions.open(item) })
            } else {
                menu.addItem(menuItem(title: "打开") {
                    for item in selectedItems { actions.open(item) }
                })
            }
            menu.addItem(.separator())
            menu.addItem(menuItem(title: "放回原处") { actions.putBack(selectedItems) })
            menu.addItem(menuItem(title: "立刻删除", destructive: true) {
                actions.deleteImmediately(selectedItems)
            })
            menu.addItem(.separator())
            menu.addItem(menuItem(title: "清倒废纸篓", destructive: true) { actions.emptyTrash() })
            return menu
        }
        
        guard !fileSelection.isEmpty else { return nil }
        
        let destination = FileOperations.pasteDestination(
            selectedItems: fileSelection,
            currentDirectoryPath: currentDirectoryPath
        )
        let showPaste = actions.canPaste(destination)
        
        if showPaste {
            menu.addItem(menuItem(title: "粘贴") { actions.paste(destination) })
            menu.addItem(.separator())
        }
        
        if fileSelection.count == 1, let item = fileSelection.first {
            menu.addItem(menuItem(title: "打开") { actions.open(item) })
            if !item.isDirectory {
                menu.addItem(menuItem(title: "打开方式…") { actions.openWith(item) })
            }
            if item.isDirectory, !actions.isFavorited(item) {
                menu.addItem(menuItem(title: "收藏") { actions.addToFavorites(item) })
            }
            menu.addItem(.separator())
        } else {
            menu.addItem(menuItem(title: "打开") {
                for item in fileSelection { actions.open(item) }
            })
            menu.addItem(.separator())
        }
        
        menu.addItem(menuItem(title: "剪切") { actions.cut(fileSelection) })
        menu.addItem(menuItem(title: "复制") { actions.copy(fileSelection) })
        menu.addItem(.separator())
        
        if fileSelection.count == 1, let item = fileSelection.first {
            menu.addItem(menuItem(title: "复制文件名") { actions.copyFilename(item) })
        }
        menu.addItem(menuItem(title: "复制完整路径") { actions.copyPaths(fileSelection) })
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "删除", destructive: true) { actions.delete(fileSelection) })
        
        if fileSelection.count == 1, let item = fileSelection.first {
            menu.addItem(menuItem(title: "重命名") { actions.rename(item) })
            menu.addItem(.separator())
            menu.addItem(menuItem(title: "在此处打开终端") { actions.openTerminal(item) })
        }
        
        menu.addItem(menuItem(title: "属性") { actions.showInfo(fileSelection) })
        return menu
    }
    
    private static func menuItem(
        title: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = CallbackMenuItem(title: title, isDestructive: destructive, action: action)
        return item
    }
}

private final class CallbackMenuItem: NSMenuItem {
    private let callback: () -> Void
    
    init(title: String, isDestructive: Bool, action: @escaping () -> Void) {
        callback = action
        super.init(title: title, action: #selector(performAction), keyEquivalent: "")
        target = self
        if isDestructive {
            self.attributedTitle = NSAttributedString(
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
