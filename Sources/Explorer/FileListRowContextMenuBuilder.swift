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
            menu.addItem(menuItem(title: "打开") { actions.open(item) })
            menu.addItem(menuItem(title: "在新窗口中打开") { actions.openInNewWindow(item) })
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
            if isNavigableFolder(item) {
                menu.addItem(menuItem(title: "在新窗口中打开") { actions.openInNewWindow(item) })
            }
            if !item.isDirectory {
                menu.addItem(openWithMenuItem(primaryItem: item, selectedItems: fileSelection, actions: actions))
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

        SnippetsContextMenuBuilder.appendSnippetsMenu(
            to: menu,
            cwd: currentDirectoryPath,
            selectedItems: selectedItems,
            showHiddenFiles: showHiddenFiles
        )

        let fileURLs = fileSelection.map(\.url)
        FileServicesMenuSupport.appendToMenu(menu, fileURLs: fileURLs)
        
        menu.addItem(menuItem(title: "属性") { actions.showInfo(fileSelection) })
        return menu
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
        let menuItem = NSMenuItem(title: "打开方式", action: nil, keyEquivalent: "")
        menuItem.submenu = makeOpenWithSubmenu(primaryItem: primaryItem, selectedItems: selectedItems, actions: actions)
        return menuItem
    }

    private static func makeOpenWithSubmenu(
        primaryItem: FileItem,
        selectedItems: [FileItem],
        actions: FileContextActions
    ) -> NSMenu {
        let submenu = NSMenu()
        // 不显示 state 列可显著减少左侧留白，让图标更靠左、更紧凑。
        submenu.showsStateColumn = false

        let openableItems = selectedItems.filter { !$0.isDirectory }
        guard !openableItems.isEmpty else {
            let disabled = NSMenuItem(title: "（无可用应用）", action: nil, keyEquivalent: "")
            disabled.isEnabled = false
            submenu.addItem(disabled)
            return submenu
        }

        let fileURL = primaryItem.url
        let workspace = NSWorkspace.shared
        let defaultApp = defaultApplicationURL(for: fileURL)
        let candidates = applicationURLs(for: fileURL)
        let uniqueApps: [URL] = {
            var seen = Set<String>()
            var result: [URL] = []
            for url in candidates {
                let key = url.resolvingSymlinksInPath().path
                if seen.insert(key).inserted { result.append(url) }
            }
            return result
        }()

        func addAppItem(appURL: URL, isDefault: Bool) {
            let title = isDefault ? "\(appDisplayName(appURL))（默认）" : appDisplayName(appURL)
            let item = CallbackMenuItem(title: title, isDestructive: false) {
                actions.openWithApplication(openableItems, appURL)
            }
            item.image = workspace.icon(forFile: appURL.path)
            configureAppMenuItemAppearance(item)
            submenu.addItem(item)
        }

        if let defaultApp {
            addAppItem(appURL: defaultApp, isDefault: true)
            if !uniqueApps.isEmpty { submenu.addItem(.separator()) }
        }

        let sortedApps = uniqueApps
            .filter { $0 != defaultApp }
            .sorted { appDisplayName($0).localizedStandardCompare(appDisplayName($1)) == .orderedAscending }

        for appURL in sortedApps.prefix(10) {
            addAppItem(appURL: appURL, isDefault: false)
        }

        submenu.addItem(.separator())
        submenu.addItem(menuItem(title: "其他…") { actions.openWith(primaryItem) })
        return submenu
    }

    private static func configureAppMenuItemAppearance(_ item: NSMenuItem) {
        // 更小的图标 + 取消缩进，视觉更紧凑、图标更靠左
        item.indentationLevel = 0
        if let image = item.image {
            image.size = NSSize(width: 16, height: 16)
            image.isTemplate = false
            item.image = image
        }
    }

    private static func defaultApplicationURL(for fileURL: URL) -> URL? {
        if #available(macOS 12.0, *) {
            return NSWorkspace.shared.urlForApplication(toOpen: fileURL)
        }
        return LSCopyDefaultApplicationURLForURL(
            fileURL as CFURL,
            .all,
            nil
        )?.takeRetainedValue() as URL?
    }

    private static func applicationURLs(for fileURL: URL) -> [URL] {
        if #available(macOS 12.0, *) {
            return NSWorkspace.shared.urlsForApplications(toOpen: fileURL)
        }
        guard let urls = LSCopyApplicationURLsForURL(fileURL as CFURL, .all)?
            .takeRetainedValue() as? [URL] else {
            return []
        }
        return urls
    }

    private static func appDisplayName(_ appURL: URL) -> String {
        if let bundle = Bundle(url: appURL) {
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !name.isEmpty {
                return name
            }
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
                return name
            }
        }
        return appURL.deletingPathExtension().lastPathComponent
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
