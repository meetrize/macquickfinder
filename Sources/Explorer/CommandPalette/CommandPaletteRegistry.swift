import FileList
import Foundation

@MainActor
enum CommandPaletteRegistry {
    static let commonSeedIDs: [CommandPaletteID] = [
        "focus_search",
        "toggle_left_panel",
        "toggle_snippets",
        "connect_server",
        "new_tab",
        "open_settings",
        "customize_toolbar",
        "open_help_cheat_sheet",
    ]

    private static let definitions: [CommandPaletteDefinition] = [
        // MARK: - Navigation
        CommandPaletteDefinition(
            id: "focus_search",
            title: { _ in L10n.Search.focus },
            category: L10n.Help.sectionTitle("navigation"),
            keywords: ["search", "find", "global", "搜索", "查找"],
            shortcutDisplay: "⌘F",
            priority: 100,
            isEnabled: { _ in true },
            perform: { $0.focusSearch() }
        ),
        CommandPaletteDefinition(
            id: "back",
            title: { _ in L10n.Pathbar.back },
            category: L10n.Help.sectionTitle("navigation"),
            keywords: ["back", "history", "后退", "返回"],
            shortcutDisplay: "⌘[",
            priority: 90,
            isEnabled: { $0.canNavigateBack },
            perform: { $0.navigateBack() }
        ),
        CommandPaletteDefinition(
            id: "forward",
            title: { _ in L10n.Pathbar.forward },
            category: L10n.Help.sectionTitle("navigation"),
            keywords: ["forward", "history", "前进"],
            shortcutDisplay: "⌘]",
            priority: 89,
            isEnabled: { $0.canNavigateForward },
            perform: { $0.navigateForward() }
        ),
        CommandPaletteDefinition(
            id: "go_up",
            title: { _ in L10n.Pathbar.parent },
            category: L10n.Help.sectionTitle("navigation"),
            keywords: ["up", "parent", "上级", "返回上级"],
            shortcutDisplay: nil,
            priority: 88,
            isEnabled: { $0.canNavigateUp },
            perform: { $0.navigateUp() }
        ),
        CommandPaletteDefinition(
            id: "connect_server",
            title: { _ in L10n.RemoteServer.connectServerMenu },
            category: L10n.Help.sectionTitle("remote_server"),
            keywords: ["server", "remote", "smb", "ftp", "连接", "服务器"],
            shortcutDisplay: "⌘K",
            priority: 85,
            isEnabled: { _ in true },
            perform: { $0.presentConnectServer() }
        ),
        CommandPaletteDefinition(
            id: "new_window",
            title: { _ in L10n.Toolbar.newWindow },
            category: L10n.Help.sectionTitle("layout"),
            keywords: ["window", "新窗口"],
            shortcutDisplay: "⌘N",
            priority: 84,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.newWindow, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "new_tab",
            title: { _ in L10n.Toolbar.newTab },
            category: L10n.Help.sectionTitle("layout"),
            keywords: ["tab", "新标签"],
            shortcutDisplay: ShortcutBinding.defaultNewTab.displayString,
            priority: 83,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.newTab, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "show_all_tabs",
            title: { _ in L10n.Toolbar.showAllTabs },
            category: L10n.Help.sectionTitle("layout"),
            keywords: ["tabs", "overview", "标签"],
            shortcutDisplay: "⌘⇧\\",
            priority: 82,
            isEnabled: { $0.tabBarState.isTabbingAvailable && $0.tabBarState.tabCount > 1 },
            perform: { ToolbarBuiltinDispatcher.perform(.showAllTabs, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "toggle_tab_bar",
            title: { context in
                context.tabBarState.isVisible ? L10n.Toolbar.hideTabBar : L10n.Toolbar.showTabBar
            },
            category: L10n.Help.sectionTitle("layout"),
            keywords: ["tab bar", "标签栏"],
            shortcutDisplay: nil,
            priority: 81,
            isEnabled: { $0.tabBarState.isTabbingAvailable },
            perform: { ToolbarBuiltinDispatcher.perform(.toggleTabBar, environment: $0.toolbarEnvironment) }
        ),

        // MARK: - Panels
        CommandPaletteDefinition(
            id: "toggle_left_panel",
            title: { _ in L10n.Menu.toggleLeftPanel },
            category: L10n.Help.sectionTitle("sidebar"),
            keywords: ["sidebar", "left", "侧栏", "左侧面板"],
            shortcutDisplay: "⌘B",
            priority: 80,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.leftPanel, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "toggle_right_panel",
            title: { _ in L10n.Menu.toggleRightPanel },
            category: L10n.Help.sectionTitle("layout"),
            keywords: ["right", "panel", "右侧面板"],
            shortcutDisplay: "⌘⇧B",
            priority: 79,
            isEnabled: { _ in true },
            perform: { $0.layout.toggleRightPanel() }
        ),
        CommandPaletteDefinition(
            id: "toggle_preview",
            title: { context in
                context.layout.showPreview ? L10n.Menu.hidePreview : L10n.Menu.showPreview
            },
            category: L10n.Help.sectionTitle("preview"),
            keywords: ["preview", "预览"],
            shortcutDisplay: nil,
            priority: 78,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.preview, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "toggle_snippets",
            title: { context in
                context.layout.showSnippets ? L10n.Menu.hideSnippets : L10n.Menu.showSnippets
            },
            category: L10n.Help.sectionTitle("snippets"),
            keywords: ["snippets", "片段"],
            shortcutDisplay: "⌘⇧S",
            priority: 77,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.snippets, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "toggle_git",
            title: { context in
                context.layout.showGit ? L10n.Menu.hideGit : L10n.Menu.showGit
            },
            category: L10n.Help.sectionTitle("snippets"),
            keywords: ["git", "版本控制"],
            shortcutDisplay: "⌘⇧G",
            priority: 76,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.git, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "toggle_output",
            title: { context in
                context.layout.isOutputPanelVisible ? L10n.Menu.hideOutputPanel : L10n.Menu.showOutputPanel
            },
            category: L10n.Help.sectionTitle("output"),
            keywords: ["output", "terminal", "shell", "输出"],
            shortcutDisplay: "⌘J",
            priority: 75,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.outputPanel, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "detach_preview",
            title: { _ in L10n.Menu.openPreviewDetached },
            category: L10n.Help.sectionTitle("preview"),
            keywords: ["detach", "分离", "预览"],
            shortcutDisplay: "⌘⌥P",
            priority: 74,
            isEnabled: { $0.previewDetach?.canDetach == true },
            perform: { $0.previewDetach?.detachPreview?() }
        ),
        CommandPaletteDefinition(
            id: "dock_preview",
            title: { _ in L10n.Menu.reattachPreview },
            category: L10n.Help.sectionTitle("preview"),
            keywords: ["dock", "attach", "停靠", "预览"],
            shortcutDisplay: nil,
            priority: 73,
            isEnabled: { $0.previewDetach?.canDock == true },
            perform: { $0.previewDetach?.dockPreview?() }
        ),
        CommandPaletteDefinition(
            id: "preview_previous",
            title: { _ in L10n.Menu.previousPreview },
            category: L10n.Help.sectionTitle("preview"),
            keywords: ["previous", "上一张", "预览"],
            shortcutDisplay: nil,
            priority: 72,
            isEnabled: { $0.previewBrowse?.canBrowsePrevious == true },
            perform: { $0.previewBrowse?.browsePrevious?() }
        ),
        CommandPaletteDefinition(
            id: "preview_next",
            title: { _ in L10n.Menu.nextPreview },
            category: L10n.Help.sectionTitle("preview"),
            keywords: ["next", "下一张", "预览"],
            shortcutDisplay: nil,
            priority: 71,
            isEnabled: { $0.previewBrowse?.canBrowseNext == true },
            perform: { $0.previewBrowse?.browseNext?() }
        ),
        CommandPaletteDefinition(
            id: "toggle_preview_strip",
            title: { context in
                context.previewBrowse?.isStripExpanded == true
                    ? L10n.Menu.collapseStrip
                    : L10n.Menu.expandStrip
            },
            category: L10n.Help.sectionTitle("preview"),
            keywords: ["strip", "browser", "预览条"],
            shortcutDisplay: "⌘⌥B",
            priority: 70,
            isEnabled: { $0.previewBrowse?.canToggleStrip == true },
            perform: { $0.previewBrowse?.toggleStrip?() }
        ),

        // MARK: - Files
        CommandPaletteDefinition(
            id: "open",
            title: { _ in L10n.Action.open },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["open", "打开"],
            shortcutDisplay: "↩",
            priority: 69,
            isEnabled: { $0.selectedItems.count == 1 },
            perform: { context in
                guard let item = context.selectedItems.first else { return }
                context.fileActions.open(item)
            }
        ),
        CommandPaletteDefinition(
            id: "cut",
            title: { _ in L10n.Action.cut },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["cut", "剪切"],
            shortcutDisplay: "⌘X",
            priority: 68,
            isEnabled: { $0.fileHandlers.canCut },
            perform: { $0.fileHandlers.cut?() }
        ),
        CommandPaletteDefinition(
            id: "copy",
            title: { _ in L10n.Action.copy },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["copy", "复制"],
            shortcutDisplay: "⌘C",
            priority: 67,
            isEnabled: { $0.fileHandlers.canCopy },
            perform: { $0.fileHandlers.copy?() }
        ),
        CommandPaletteDefinition(
            id: "paste",
            title: { _ in L10n.Action.paste },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["paste", "粘贴"],
            shortcutDisplay: "⌘V",
            priority: 66,
            isEnabled: { $0.fileHandlers.canPaste },
            perform: { $0.fileHandlers.paste?() }
        ),
        CommandPaletteDefinition(
            id: "delete",
            title: { _ in L10n.Action.delete },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["delete", "remove", "删除"],
            shortcutDisplay: "⌫",
            priority: 65,
            isEnabled: { $0.fileHandlers.canDelete },
            perform: { $0.fileHandlers.delete?() }
        ),
        CommandPaletteDefinition(
            id: "rename",
            title: { _ in L10n.Action.rename },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["rename", "重命名"],
            shortcutDisplay: "F2",
            priority: 64,
            isEnabled: { $0.selectedItems.count == 1 && !$0.selectedItems[0].isParentDirectoryEntry },
            perform: { context in
                guard let item = context.selectedItems.first else { return }
                context.fileActions.rename(item)
            }
        ),
        CommandPaletteDefinition(
            id: "copy_path",
            title: { _ in L10n.Action.copyPaths },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["path", "copy", "路径"],
            shortcutDisplay: ShortcutBinding.defaultCopyPath.displayString,
            priority: 63,
            isEnabled: { !$0.selectedItems.isEmpty },
            perform: { context in
                FileOperations.copyPaths(context.selectedItems)
            }
        ),
        CommandPaletteDefinition(
            id: "new_folder",
            title: { _ in L10n.Toolbar.newFolder },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["folder", "新建", "文件夹"],
            shortcutDisplay: nil,
            priority: 62,
            isEnabled: { $0.blankMenuActions.isEnabled },
            perform: { ToolbarBuiltinDispatcher.perform(.newFolder, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "new_file",
            title: { _ in L10n.Toolbar.newFile },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["file", "新建", "文件"],
            shortcutDisplay: nil,
            priority: 61,
            isEnabled: { $0.blankMenuActions.isEnabled },
            perform: { ToolbarBuiltinDispatcher.perform(.newFile, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "show_info",
            title: { _ in L10n.Action.showInfo },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["info", "properties", "属性", "信息"],
            shortcutDisplay: "⌘I",
            priority: 60,
            isEnabled: { !$0.selectedItems.isEmpty },
            perform: { context in
                context.fileActions.showInfo(context.selectedItems)
            }
        ),
        CommandPaletteDefinition(
            id: "open_terminal",
            title: { _ in L10n.Action.openTerminalHere },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["terminal", "终端"],
            shortcutDisplay: nil,
            priority: 59,
            isEnabled: { $0.blankMenuActions.isEnabled },
            perform: { $0.blankMenuActions.openTerminal() }
        ),
        CommandPaletteDefinition(
            id: "empty_trash",
            title: { _ in L10n.Action.emptyTrash },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["trash", "empty", "清空", "废纸篓"],
            shortcutDisplay: nil,
            priority: 58,
            isEnabled: { $0.blankMenuActions.isInTrash },
            perform: { $0.blankMenuActions.emptyTrash() }
        ),
        CommandPaletteDefinition(
            id: "put_back",
            title: { _ in L10n.Action.putBack },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["restore", "put back", "放回原处"],
            shortcutDisplay: nil,
            priority: 57,
            isEnabled: { $0.fileActions.isInTrash && !$0.selectedItems.isEmpty },
            perform: { context in
                context.fileActions.putBack(context.selectedItems)
            }
        ),
        CommandPaletteDefinition(
            id: "refresh",
            title: { _ in L10n.Action.refresh },
            category: L10n.Help.sectionTitle("files"),
            keywords: ["refresh", "reload", "刷新"],
            shortcutDisplay: "⌘R",
            priority: 56,
            isEnabled: { $0.blankMenuActions.showRefresh },
            perform: { $0.blankMenuActions.refresh() }
        ),

        // MARK: - View
        CommandPaletteDefinition(
            id: "view_list",
            title: { _ in L10n.Help.entryName("list_view") },
            category: L10n.Help.sectionTitle("navigation"),
            keywords: ["list", "列表"],
            shortcutDisplay: nil,
            priority: 55,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.listView, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "view_thumbnail",
            title: { _ in L10n.Help.entryName("thumbnail_view") },
            category: L10n.Help.sectionTitle("navigation"),
            keywords: ["thumbnail", "缩略图"],
            shortcutDisplay: nil,
            priority: 54,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.thumbnailView, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "view_panorama",
            title: { _ in L10n.Toolbar.panoramaMode },
            category: L10n.Help.sectionTitle("navigation"),
            keywords: ["panorama", "全景"],
            shortcutDisplay: nil,
            priority: 53,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.panoramaView, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "toggle_hidden_files",
            title: { context in
                context.showHiddenFiles ? L10n.Toolbar.hideHiddenFiles : L10n.Toolbar.showHiddenFiles
            },
            category: L10n.Help.sectionTitle("navigation"),
            keywords: ["hidden", "隐藏文件"],
            shortcutDisplay: "⌘⇧.",
            priority: 52,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.toggleHiddenFiles, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "customize_toolbar",
            title: { _ in L10n.Toolbar.customize },
            category: L10n.Help.sectionTitle("toolbar"),
            keywords: ["toolbar", "customize", "工具栏"],
            shortcutDisplay: nil,
            priority: 51,
            isEnabled: { _ in true },
            perform: { $0.customizeToolbar() }
        ),

        // MARK: - Snippets / Output
        CommandPaletteDefinition(
            id: "import_snippets",
            title: { _ in L10n.Menu.importSnippets },
            category: L10n.Help.sectionTitle("snippets"),
            keywords: ["import", "snippets", "导入"],
            shortcutDisplay: nil,
            priority: 50,
            isEnabled: { _ in true },
            perform: { $0.importSnippets() }
        ),
        CommandPaletteDefinition(
            id: "export_snippets",
            title: { _ in L10n.Menu.exportSnippets },
            category: L10n.Help.sectionTitle("snippets"),
            keywords: ["export", "snippets", "导出"],
            shortcutDisplay: nil,
            priority: 49,
            isEnabled: { _ in true },
            perform: { $0.exportSnippets() }
        ),
        CommandPaletteDefinition(
            id: "toggle_operation_recording",
            title: { context in
                context.toolbarEnvironment.isOperationRecording
                    ? L10n.Toolbar.recordOperationsActive
                    : L10n.Toolbar.recordOperations
            },
            category: L10n.Help.sectionTitle("snippets"),
            keywords: ["record", "recording", "录制"],
            shortcutDisplay: nil,
            priority: 48,
            isEnabled: { _ in true },
            perform: { ToolbarBuiltinDispatcher.perform(.recordOperations, environment: $0.toolbarEnvironment) }
        ),
        CommandPaletteDefinition(
            id: "focus_output_command",
            title: { _ in L10n.Help.entryName("command_box") },
            category: L10n.Help.sectionTitle("output"),
            keywords: ["output", "command", "shell", "命令"],
            shortcutDisplay: nil,
            priority: 47,
            isEnabled: { _ in true },
            perform: { $0.focusOutputCommand() }
        ),

        // MARK: - System
        CommandPaletteDefinition(
            id: "open_settings",
            title: { _ in L10n.Settings.menuItem },
            category: L10n.Help.sectionTitle("settings"),
            keywords: ["settings", "preferences", "设置"],
            shortcutDisplay: "⌘,",
            priority: 46,
            isEnabled: { _ in true },
            perform: { $0.openSettings() }
        ),
        CommandPaletteDefinition(
            id: "open_help_cheat_sheet",
            title: { _ in L10n.Help.cheatSheetMenu },
            category: L10n.Help.sectionTitle("settings"),
            keywords: ["help", "shortcuts", "帮助", "速查"],
            shortcutDisplay: "⌘?",
            priority: 45,
            isEnabled: { _ in true },
            perform: { $0.openHelp() }
        ),
        CommandPaletteDefinition(
            id: "command_palette",
            title: { _ in L10n.CommandPalette.menuTitle },
            category: L10n.Help.sectionTitle("settings"),
            keywords: ["palette", "commands", "命令面板"],
            shortcutDisplay: "⌘⇧P",
            priority: 44,
            isEnabled: { _ in true },
            perform: { $0.toggleCommandPalette() }
        ),
    ]

    private static let sortedDefinitions: [CommandPaletteDefinition] = definitions.sorted {
        $0.priority > $1.priority
    }

    private static let definitionByID: [CommandPaletteID: CommandPaletteDefinition] = {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }()

    private static let keywordsByID: [CommandPaletteID: [String]] = {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0.keywords) })
    }()

    static var fuzzyKeywordsByID: [CommandPaletteID: [String]] { keywordsByID }

    static func resolveBaseItems(in context: CommandPaletteContext) -> [CommandPaletteResolvedItem] {
        sortedDefinitions.map { $0.resolve(in: context) }
    }

    static func resolvedItems(in context: CommandPaletteContext) -> [CommandPaletteResolvedItem] {
        resolveBaseItems(in: context)
    }

    static func defaultList(
        from baseItems: [CommandPaletteResolvedItem],
        recents: [CommandPaletteID]
    ) -> [CommandPaletteResolvedItem] {
        let byID = Dictionary(uniqueKeysWithValues: baseItems.map { ($0.id, $0) })

        var ordered: [CommandPaletteResolvedItem] = []
        var seen = Set<CommandPaletteID>()

        for recentID in recents {
            guard let item = byID[recentID], !seen.contains(recentID) else { continue }
            ordered.append(item)
            seen.insert(recentID)
        }

        for seedID in commonSeedIDs where !seen.contains(seedID) {
            guard let item = byID[seedID] else { continue }
            ordered.append(item)
            seen.insert(seedID)
        }

        for item in baseItems where !seen.contains(item.id) {
            ordered.append(item)
            seen.insert(item.id)
        }

        return ordered
    }

    static func defaultList(in context: CommandPaletteContext) -> [CommandPaletteResolvedItem] {
        defaultList(
            from: resolveBaseItems(in: context),
            recents: CommandPaletteRecentsStore.cachedLoad()
        )
    }

    static func filteredItems(
        baseItems: [CommandPaletteResolvedItem],
        recents: [CommandPaletteID],
        query: String
    ) -> [CommandPaletteResolvedItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return defaultList(from: baseItems, recents: recents)
        }
        return CommandPaletteFuzzyMatcher.filter(
            baseItems,
            query: trimmed,
            keywordsByID: keywordsByID
        )
    }

    static func filteredItems(in context: CommandPaletteContext, query: String) -> [CommandPaletteResolvedItem] {
        filteredItems(
            baseItems: resolveBaseItems(in: context),
            recents: CommandPaletteRecentsStore.cachedLoad(),
            query: query
        )
    }

    static func perform(id: CommandPaletteID, in context: CommandPaletteContext) {
        if CommandPaletteSnippetResolver.isSnippetCommand(id) {
            CommandPaletteSnippetResolver.perform(id: id, in: context)
            return
        }
        guard let definition = definitionByID[id], definition.isEnabled(context) else { return }
        definition.perform(context)
        if id != "command_palette" {
            CommandPaletteRecentsStore.record(id)
        }
    }

    static func selectableIndices(in items: [CommandPaletteResolvedItem]) -> [Int] {
        items.enumerated().compactMap { index, item in
            item.isEnabled ? index : nil
        }
    }

    static func clampSelectionIndex(_ index: Int, in items: [CommandPaletteResolvedItem]) -> Int? {
        let selectable = selectableIndices(in: items)
        guard !selectable.isEmpty else { return nil }
        if selectable.contains(index) { return index }
        return selectable.first
    }

    static func moveSelection(from index: Int, direction: Int, in items: [CommandPaletteResolvedItem]) -> Int? {
        let selectable = selectableIndices(in: items)
        guard !selectable.isEmpty else { return nil }
        guard let currentPosition = selectable.firstIndex(of: index) else {
            return selectable.first
        }
        let nextPosition = (currentPosition + direction + selectable.count) % selectable.count
        return selectable[nextPosition]
    }
}
