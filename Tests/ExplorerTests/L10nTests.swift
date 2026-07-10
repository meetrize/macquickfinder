import XCTest
import FileList
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
        XCTAssertNotEqual(L10n.Toolbar.newFile, "toolbar.new_file")
        XCTAssertNotEqual(L10n.File.defaultNewFileName, "file.default_new_name")
        XCTAssertNotEqual(L10n.File.pastedImageBaseName, "file.pasted_image_base")
        XCTAssertNotEqual(L10n.File.pastedImageFileName, "file.pasted_image_name")
        XCTAssertNotEqual(L10n.File.pastedTextFileName, "file.pasted_text_name")
        XCTAssertNotEqual(L10n.File.pastedMarkdownFileName, "file.pasted_markdown_name")
        XCTAssertNotEqual(L10n.File.pasteCreatingFromClipboard, "file.paste_creating_from_clipboard")
        XCTAssertNotEqual(L10n.File.pasteProgress(2, 5), "file.paste_progress")
        XCTAssertNotEqual(L10n.File.pasteProgressWithName(2, 5, "demo.txt"), "file.paste_progress_with_name")
        XCTAssertNotEqual(L10n.Toolbar.autoFolderSize, "toolbar.auto_folder_size")
        XCTAssertNotEqual(L10n.Toolbar.panoramaLayoutGrid, "toolbar.panorama.layout_grid")
        XCTAssertNotEqual(L10n.Toolbar.panoramaLayoutPanorama, "toolbar.panorama.layout_panorama")
        XCTAssertNotEqual(L10n.Toolbar.panoramaMode, "toolbar.panorama_mode")
        XCTAssertNotEqual(L10n.Toolbar.panoramaExpandAll, "toolbar.panorama.expand_all")
        XCTAssertNotEqual(L10n.Toolbar.panoramaCollapseAll, "toolbar.panorama.collapse_all")
        XCTAssertNotEqual(L10n.Toolbar.panoramaExpandDepth, "toolbar.panorama.expand_depth")
        XCTAssertNotEqual(L10n.Panorama.expandDepthAutomatic, "panorama.expand_depth.automatic")
        XCTAssertNotEqual(L10n.Panorama.expandDepth2, "panorama.expand_depth.depth2")
        XCTAssertNotEqual(L10n.Toolbar.recordOperationsActive, "toolbar.record_operations_active")
        XCTAssertNotEqual(L10n.OperationRecording.noSteps, "operation_recording.no_steps")
        XCTAssertNotEqual(L10n.OperationRecording.reviewTitle, "operation_recording.review_title")
        XCTAssertNotEqual(L10n.OperationRecording.createSnippet, "operation_recording.create_snippet")
        XCTAssertNotEqual(L10n.OperationRecording.bannerStop, "operation_recording.banner.stop")
        XCTAssertNotEqual(L10n.OperationRecording.shortCompress, "operation_recording.short.compress")
        XCTAssertNotEqual(L10n.OperationRecording.scopeSuggestion("test"), "operation_recording.scope_suggestion")
        XCTAssertNotEqual(L10n.OperationRecording.trashWarning, "operation_recording.trash_warning")
        XCTAssertNotEqual(L10n.Settings.Snippets.recordingSection, "settings.snippets.recording_section")
        XCTAssertNotEqual(L10n.Settings.Snippets.outputColorScheme, "settings.snippets.output_color_scheme")
        XCTAssertNotEqual(L10n.Settings.Snippets.outputColorDark, "settings.snippets.output_color.dark")
        XCTAssertNotEqual(L10n.Settings.Snippets.outputColorLight, "settings.snippets.output_color.light")
        XCTAssertNotEqual(L10n.Settings.Snippets.outputColorGray, "settings.snippets.output_color.gray")
        XCTAssertNotEqual(L10n.Snippets.Variable.n, "snippets.variable.n")
        XCTAssertNotEqual(L10n.OperationRecording.variablesTitle, "operation_recording.variables_title")
        XCTAssertNotEqual(L10n.OperationRecording.testScript, "operation_recording.test_script")
        XCTAssertNotEqual(L10n.OperationRecording.Validation.passed, "operation_recording.validation.passed")
        XCTAssertNotEqual(L10n.Snippets.VariableHelp.columnToken, "snippets.variable_help.column_token")
        XCTAssertNotEqual(L10n.Snippets.Editor.sectionScript, "snippets.editor.section_script")
        XCTAssertNotEqual(L10n.Snippets.VariableHelp.footer, "snippets.variable_help.footer")
        XCTAssertNotEqual(L10n.Snippets.ScopeDesc.singleSelection, "snippets.scope.single_selection.desc")
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
        XCTAssertNotEqual(L10n.Settings.menuItem, "settings.menu_item")
        XCTAssertNotEqual(L10n.Settings.windowTitle, "settings.window_title")
        XCTAssertNotEqual(L10n.Settings.Preview.ArchiveDoubleClick.extract, "settings.preview.archive_double_click.extract")
        XCTAssertNotEqual(L10n.Settings.Preview.ExternalMultiImage.singleWindowWithStrip, "settings.preview.external_multi_image.single_window_with_strip")
        XCTAssertNotEqual(L10n.Settings.Preview.HandlerGroup.pdf, "settings.preview.handler_group.pdf")
        XCTAssertNotEqual(L10n.Archive.jobCompress, "archive.job.compress")
        XCTAssertNotEqual(L10n.Preview.Toolbar.extract, "preview.toolbar.extract")
        XCTAssertNotEqual(L10n.Preview.Toolbar.runScript, "preview.toolbar.run_script")
        XCTAssertNotEqual(L10n.Preview.Toolbar.extractSelected, "preview.toolbar.extract_selected")
        XCTAssertNotEqual(L10n.Preview.Toolbar.previousMatch, "preview.toolbar.previous_match")
        XCTAssertNotEqual(L10n.Preview.Toolbar.clearSearch, "preview.toolbar.clear_search")
        XCTAssertNotEqual(L10n.Preview.Toolbar.searchNoResults, "preview.toolbar.search_no_results")
        XCTAssertNotEqual(L10n.Preview.TextEdit.edit, "preview.text_edit.edit")
        XCTAssertNotEqual(L10n.Preview.TextEdit.save, "preview.text_edit.save")
        XCTAssertNotEqual(L10n.Preview.TextEdit.tooLarge, "preview.text_edit.too_large")
        XCTAssertNotEqual(L10n.Preview.Archive.loadingMore, "preview.archive.loading_more")
        XCTAssertNotEqual(L10n.Preview.Chrome.revealInFileList, "preview.chrome.reveal_in_file_list")
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
        XCTAssertNotEqual(L10n.Settings.Shortcuts.copyPath, "settings.shortcut.copy_path")
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
        XCTAssertNotEqual(L10n.Settings.Git.title, "settings.git.title")
        XCTAssertNotEqual(L10n.Settings.Git.choose, "settings.git.choose")
        XCTAssertNotEqual(L10n.Settings.Git.notFound, "settings.git.not_found")
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

    func testMarkdownMermaidPreviewStringsResolve() {
        XCTAssertNotEqual(L10n.Preview.Markdown.mermaidRendering, "preview.markdown.mermaid_rendering")
        XCTAssertNotEqual(L10n.Preview.Markdown.mermaidRenderFailed, "preview.markdown.mermaid_render_failed")
        XCTAssertNotEqual(L10n.Preview.Epub.chapterProgress(1, 3), "preview.epub.chapter_progress %lld %lld")
        XCTAssertNotEqual(L10n.Preview.Epub.noChapters, "preview.epub.no_chapters")
        XCTAssertNotEqual(L10n.Preview.Toolbar.epubChapters, "preview.toolbar.epub_chapters")
        XCTAssertNotEqual(L10n.Error.Epub.unzipFailed, "error.epub.unzip_failed")
        XCTAssertNotEqual(L10n.Preview.Eml.from, "preview.eml.from")
        XCTAssertNotEqual(L10n.Preview.Eml.attachments, "preview.eml.attachments")
        XCTAssertNotEqual(L10n.Error.Eml.invalidFormat, "error.eml.invalid_format")
        XCTAssertNotEqual(L10n.Preview.Font.family, "preview.font.family")
        XCTAssertNotEqual(L10n.Error.Font.unableToLoad, "error.font.unable_to_load")
    }

    func testMoveBlockedAlertStringsResolve() {
        XCTAssertNotEqual(L10n.Alert.moveBlockedTitle, "alert.move_blocked.title")
        XCTAssertNotEqual(
            L10n.Alert.moveBlockedMessage(.alreadyInDestination),
            "alert.move_blocked.already_in_destination"
        )
        XCTAssertNotEqual(
            L10n.Alert.moveBlockedMessage(.sourceMissing),
            "alert.move_blocked.source_missing"
        )
    }

    private func localizedBundle(language: String, parent: Bundle) -> Bundle? {
        guard let path = parent.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
