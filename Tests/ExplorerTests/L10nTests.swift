import XCTest
@testable import Explorer

final class ExplorerL10nTests: XCTestCase {
    func testExplorerResourceBundleContainsCatalog() throws {
        let bundle = Bundle.module
        let catalogPath = bundle.path(forResource: "Localizable", ofType: "xcstrings")
        XCTAssertNotNil(catalogPath, "Explorer Localizable.xcstrings should exist in resource bundle")
    }

    func testExplorerLocalizedStringsResolve() {
        XCTAssertFalse(L10n.Sidebar.favorites.isEmpty)
        XCTAssertFalse(L10n.Sidebar.trash.isEmpty)
        XCTAssertFalse(L10n.Settings.Tab.general.isEmpty)
        XCTAssertNotEqual(L10n.Sidebar.favorites, "sidebar.favorites")
        XCTAssertNotEqual(L10n.Sidebar.trash, "sidebar.trash")
        XCTAssertNotEqual(L10n.Sidebar.disconnectDevice("remote"), "sidebar.disconnect_device remote")
        XCTAssertNotEqual(L10n.Toolbar.customize, "toolbar.customize")
        XCTAssertNotEqual(L10n.Toolbar.customizeTitle, "toolbar.customize.title")
        XCTAssertNotEqual(L10n.Toolbar.customizeDone, "toolbar.customize.done")
        XCTAssertNotEqual(L10n.Toolbar.openAppSelectionPolicy, "toolbar.open_app.selection_policy")
        XCTAssertNotEqual(L10n.Toolbar.openAppSelectionCurrentFolder, "toolbar.open_app.selection_current_folder")
        XCTAssertNotEqual(L10n.Toolbar.openAppEdit, "toolbar.open_app.edit")
        XCTAssertNotEqual(L10n.Toolbar.newWindow, "toolbar.new_window")
        XCTAssertNotEqual(L10n.Toolbar.newTab, "toolbar.new_tab")
        XCTAssertNotEqual(L10n.Toolbar.showAllTabs, "toolbar.show_all_tabs")
        XCTAssertNotEqual(L10n.Toolbar.showTabBar, "toolbar.show_tab_bar")
        XCTAssertNotEqual(L10n.Toolbar.hideTabBar, "toolbar.hide_tab_bar")
        XCTAssertNotEqual(L10n.Toolbar.tabBarCannotHideMultiple, "toolbar.tab_bar.cannot_hide_multiple")
        XCTAssertNotEqual(L10n.Settings.Shortcuts.newTab, "settings.shortcut.new_tab")
        XCTAssertNotEqual(L10n.Action.compressOne("demo"), "action.compress_one demo")
        XCTAssertNotEqual(L10n.Action.extractHere, "action.extract_here")
        XCTAssertNotEqual(L10n.Action.openInDetachedPreview, "action.open_in_detached_preview")
        XCTAssertNotEqual(L10n.Settings.Preview.DoubleClick.defaultApp, "settings.preview.double_click.default_app")
        XCTAssertNotEqual(L10n.Settings.Preview.ArchiveDoubleClick.extract, "settings.preview.archive_double_click.extract")
        XCTAssertNotEqual(L10n.Settings.Preview.ExternalMultiImage.singleWindowWithStrip, "settings.preview.external_multi_image.single_window_with_strip")
        XCTAssertNotEqual(L10n.Settings.Preview.HandlerGroup.pdf, "settings.preview.handler_group.pdf")
        XCTAssertNotEqual(L10n.Archive.jobCompress, "archive.job.compress")
        XCTAssertNotEqual(L10n.Preview.Toolbar.extract, "preview.toolbar.extract")
        XCTAssertNotEqual(L10n.Preview.Toolbar.extractSelected, "preview.toolbar.extract_selected")
        XCTAssertNotEqual(L10n.Preview.Archive.loadingMore, "preview.archive.loading_more")
        XCTAssertNotEqual(L10n.Settings.Preview.customize, "settings.preview.customize")
        XCTAssertNotEqual(L10n.Settings.Preview.Mode.archive, "settings.preview.mode.archive")
        XCTAssertNotEqual(L10n.Archive.passwordTitle, "archive.password.title")
    }

    func testExplorerEnglishStringsMatchCatalog() {
        guard let enBundle = localizedBundle(language: "en", parent: Bundle.module) else {
            // SPM 可能仅打包 xcstrings；回退验证运行时解析结果
            XCTAssertTrue(L10n.Sidebar.favorites == "Favorites" || L10n.Sidebar.favorites == "个人收藏")
            return
        }
        XCTAssertEqual(
            enBundle.localizedString(forKey: "sidebar.favorites", value: nil, table: nil),
            "Favorites"
        )
        XCTAssertEqual(
            enBundle.localizedString(forKey: "sidebar.trash", value: nil, table: nil),
            "Trash"
        )
    }

    func testExplorerChineseStringsMatchCatalog() {
        guard let zhBundle = localizedBundle(language: "zh-Hans", parent: Bundle.module) else {
            return
        }
        XCTAssertEqual(
            zhBundle.localizedString(forKey: "sidebar.favorites", value: nil, table: nil),
            "个人收藏"
        )
        XCTAssertEqual(
            zhBundle.localizedString(forKey: "sidebar.trash", value: nil, table: nil),
            "废纸篓"
        )
    }

    func testShortcutsSettingsStringsResolve() {
        XCTAssertNotEqual(L10n.Settings.Tab.shortcuts, "settings.tab.shortcuts")
        XCTAssertNotEqual(L10n.Settings.Shortcuts.globalToggle, "settings.shortcut.global_toggle")
        XCTAssertNotEqual(L10n.Settings.Shortcuts.globalToggleEnabled, "settings.shortcut.global_toggle_enabled")
        XCTAssertNotEqual(L10n.Settings.Shortcuts.cheatSheet, "settings.shortcut.cheat_sheet")
        XCTAssertNotEqual(L10n.Settings.Shortcuts.category("global"), "settings.shortcuts.category.global")
        XCTAssertNotEqual(L10n.Settings.Shortcuts.category("navigation"), "settings.shortcuts.category.navigation")
        XCTAssertNotEqual(L10n.Settings.General.fileListRowHover, "settings.file_list.row_hover_highlight")
    }

    func testHelpStringsResolveFromStringsTable() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: ModuleLocalization.preferenceKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: ModuleLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: ModuleLocalization.preferenceKey)
            }
            _ = ModuleLocalization.setLanguage(InterfaceLanguage(rawValue: previous ?? "") ?? .system)
        }

        XCTAssertTrue(ModuleLocalization.setLanguage(.zhHans))
        XCTAssertEqual(L10n.Help.windowTitle, "MeoFind 功能速查表")
        XCTAssertEqual(L10n.Help.cheatSheetMenu, "功能速查表")
        XCTAssertEqual(L10n.Help.entryName("file_list"), "文件列表")
        XCTAssertNotEqual(L10n.Help.entryName("file_list"), "help.entry.file_list.name")
        XCTAssertEqual(L10n.Help.entryName("toolbar_customize"), "自定义工具栏")
        XCTAssertNotEqual(L10n.Help.entryName("toolbar_customize"), "help.entry.toolbar_customize.name")
        XCTAssertEqual(L10n.Help.sectionTitle("toolbar"), "工具栏")
        XCTAssertEqual(L10n.Help.entryName("connect_server"), "连接服务器")
        XCTAssertNotEqual(L10n.Help.entryName("connect_server"), "help.entry.connect_server.name")
        XCTAssertEqual(L10n.Help.entryShortcut("connect_server"), "⌘K")
    }

    func testDefaultViewerStringsResolve() {
        XCTAssertNotEqual(L10n.Settings.DefaultViewer.title, "settings.default_viewer.title")
        XCTAssertNotEqual(L10n.Settings.DefaultViewer.setSuccess, "settings.default_viewer.set_success")
        XCTAssertNotEqual(L10n.Settings.DefaultViewer.restoreSuccess, "settings.default_viewer.restore_success")
        XCTAssertNotEqual(
            L10n.Error.DefaultViewer.launchServices(-50),
            "error.default_viewer.launch_services %lld"
        )
        XCTAssertTrue(L10n.Error.DefaultViewer.launchServices(-50).contains("-50"))
    }

    func testPreviewHandlerGroupImageHintResolves() {
        XCTAssertNotEqual(
            L10n.Settings.Preview.HandlerGroup.imageHint,
            "settings.preview.handler_group.image.hint"
        )
    }

    func testWordDocumentPreviewToolbarStringsResolve() {
        XCTAssertNotEqual(L10n.Preview.Toolbar.wordDocumentToFormatted, "preview.toolbar.word_document_to_formatted")
        XCTAssertNotEqual(L10n.Preview.Toolbar.wordDocumentToText, "preview.toolbar.word_document_to_text")
    }

    private func localizedBundle(language: String, parent: Bundle) -> Bundle? {
        guard let path = parent.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
