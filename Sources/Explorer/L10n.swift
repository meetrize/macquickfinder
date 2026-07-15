import Foundation
import FileList

/// 类型安全的本地化字符串访问层。
enum L10n {
    enum Sidebar {
        static var favorites: String { ModuleLocalization.localized("sidebar.favorites", bundle: .module) }
        static var devices: String { ModuleLocalization.localized("sidebar.devices", bundle: .module) }
        static var locations: String { ModuleLocalization.localized("sidebar.locations", bundle: .module) }
        static var trash: String { ModuleLocalization.localized("sidebar.trash", bundle: .module) }
        static var noDevices: String { ModuleLocalization.localized("sidebar.no_devices", bundle: .module) }

        static func ejectDevice(_ name: String) -> String {
            ModuleLocalization.localized("sidebar.eject_device \(name)", bundle: .module)
        }

        static func disconnectDevice(_ name: String) -> String {
            ModuleLocalization.localized("sidebar.disconnect_device \(name)", bundle: .module)
        }

        static func ejectFailed(_ name: String) -> String {
            ModuleLocalization.localized("sidebar.eject_failed \(name)", bundle: .module)
        }
    }

    enum SystemFolder {
        static var home: String { ModuleLocalization.localized("folder.home", bundle: .module) }
        static var desktop: String { ModuleLocalization.localized("folder.desktop", bundle: .module) }
        static var documents: String { ModuleLocalization.localized("folder.documents", bundle: .module) }
        static var downloads: String { ModuleLocalization.localized("folder.downloads", bundle: .module) }
    }

    enum Action {
        static var open: String { ModuleLocalization.localized("action.open", bundle: .module) }
        static var openInNewWindow: String { ModuleLocalization.localized("action.open_in_new_window", bundle: .module) }
        static var openInDetachedPreview: String { ModuleLocalization.localized("action.open_in_detached_preview", bundle: .module) }
        static var openWith: String { ModuleLocalization.localized("action.open_with", bundle: .module) }
        static var openWithNone: String { ModuleLocalization.localized("action.open_with_none", bundle: .module) }
        static var openWithOther: String { ModuleLocalization.localized("action.open_with_other", bundle: .module) }
        static var cut: String { ModuleLocalization.localized("action.cut", bundle: .module) }
        static var copy: String { ModuleLocalization.localized("action.copy", bundle: .module) }
        static var paste: String { ModuleLocalization.localized("action.paste", bundle: .module) }
        static var delete: String { ModuleLocalization.localized("action.delete", bundle: .module) }
        static var rename: String { ModuleLocalization.localized("action.rename", bundle: .module) }
        static var refresh: String { ModuleLocalization.localized("action.refresh", bundle: .module) }
        static var cancel: String { ModuleLocalization.localized("action.cancel", bundle: .module) }
        static var save: String { ModuleLocalization.localized("action.save", bundle: .module) }
        static var ok: String { ModuleLocalization.localized("action.ok", bundle: .module) }
        static var edit: String { ModuleLocalization.localized("action.edit", bundle: .module) }
        static var removeFavorite: String { ModuleLocalization.localized("action.remove_favorite", bundle: .module) }
        static var addFavorite: String { ModuleLocalization.localized("action.add_favorite", bundle: .module) }
        static var emptyTrash: String { ModuleLocalization.localized("action.empty_trash", bundle: .module) }
        static var putBack: String { ModuleLocalization.localized("action.put_back", bundle: .module) }
        static var deleteImmediately: String { ModuleLocalization.localized("action.delete_immediately", bundle: .module) }
        static var copyFilename: String { ModuleLocalization.localized("action.copy_filename", bundle: .module) }
        static var copyPaths: String { ModuleLocalization.localized("action.copy_paths", bundle: .module) }
        static var showInfo: String { ModuleLocalization.localized("action.show_info", bundle: .module) }
        static var services: String { ModuleLocalization.localized("action.services", bundle: .module) }
        static var openTerminalHere: String { ModuleLocalization.localized("action.open_terminal_here", bundle: .module) }
        static var extract: String { ModuleLocalization.localized("action.extract", bundle: .module) }
        static var extractHere: String { ModuleLocalization.localized("action.extract_here", bundle: .module) }
        static var extractTo: String { ModuleLocalization.localized("action.extract_to", bundle: .module) }
        static var extractDownloads: String { ModuleLocalization.localized("action.extract_downloads", bundle: .module) }

        static func compressOne(_ name: String) -> String {
            ModuleLocalization.localized("action.compress_one \(name)", bundle: .module)
        }

        static func compressMany(_ count: Int) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("action.compress_many %lld", bundle: .module),
                Int64(count)
            )
        }

        static func openWithDefault(_ appName: String) -> String {
            ModuleLocalization.localized("action.open_with_default \(appName)", bundle: .module)
        }
    }

    enum Menu {
        static var toggleLeftPanel: String { ModuleLocalization.localized("menu.toggle_left_panel", bundle: .module) }
        static var toggleRightPanel: String { ModuleLocalization.localized("menu.toggle_right_panel", bundle: .module) }
        static var hidePreview: String { ModuleLocalization.localized("menu.hide_preview", bundle: .module) }
        static var showPreview: String { ModuleLocalization.localized("menu.show_preview", bundle: .module) }
        static var hideSnippets: String { ModuleLocalization.localized("menu.hide_snippets", bundle: .module) }
        static var showSnippets: String { ModuleLocalization.localized("menu.show_snippets", bundle: .module) }
        static var hideGit: String { ModuleLocalization.localized("menu.hide_git", bundle: .module) }
        static var showGit: String { ModuleLocalization.localized("menu.show_git", bundle: .module) }
        static var hideOutputPanel: String { ModuleLocalization.localized("menu.hide_output", bundle: .module) }
        static var showOutputPanel: String { ModuleLocalization.localized("menu.show_output", bundle: .module) }
        static var importSnippets: String { ModuleLocalization.localized("menu.import_snippets", bundle: .module) }
        static var exportSnippets: String { ModuleLocalization.localized("menu.export_snippets", bundle: .module) }
        static var openPreviewDetached: String { ModuleLocalization.localized("menu.open_preview_detached", bundle: .module) }
        static var reattachPreview: String { ModuleLocalization.localized("menu.reattach_preview", bundle: .module) }
        static var previousPreview: String { ModuleLocalization.localized("menu.previous_preview", bundle: .module) }
        static var nextPreview: String { ModuleLocalization.localized("menu.next_preview", bundle: .module) }
        static var collapseStrip: String { ModuleLocalization.localized("menu.collapse_strip", bundle: .module) }
        static var expandStrip: String { ModuleLocalization.localized("menu.expand_strip", bundle: .module) }
        static var go: String { ModuleLocalization.localized("menu.go", bundle: .module) }
    }

    enum Git {
        enum Panel {
            static var title: String { ModuleLocalization.localized("git.panel.title", bundle: .module) }
            static var close: String { ModuleLocalization.localized("git.panel.close", bundle: .module) }
            static var collapse: String { ModuleLocalization.localized("git.panel.collapse", bundle: .module) }
            static var expand: String { ModuleLocalization.localized("git.panel.expand", bundle: .module) }
            static var placeholder: String { ModuleLocalization.localized("git.panel.placeholder", bundle: .module) }
            static var refresh: String { ModuleLocalization.localized("git.panel.refresh", bundle: .module) }
            static var configureGit: String { ModuleLocalization.localized("git.panel.configure_git", bundle: .module) }
            static var configureGitHint: String { ModuleLocalization.localized("git.panel.configure_git_hint", bundle: .module) }
        }

        enum Status {
            static var clean: String { ModuleLocalization.localized("git.status.clean", bundle: .module) }
            static var conflict: String { ModuleLocalization.localized("git.status.conflict", bundle: .module) }
            static var pendingCommit: String { ModuleLocalization.localized("git.status.pending_commit", bundle: .module) }

            static func dirty(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.status.dirty %lld", bundle: .module),
                    Int64(count)
                )
            }

            static func ahead(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.status.ahead %lld", bundle: .module),
                    Int64(count)
                )
            }

            static func behind(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.status.behind %lld", bundle: .module),
                    Int64(count)
                )
            }

            static func changes(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.status.changes %lld", bundle: .module),
                    Int64(count)
                )
            }

            static func moreChanges(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.status.more_changes %lld", bundle: .module),
                    Int64(count)
                )
            }
        }

        enum Chip {
            static func ahead(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.chip.ahead %lld", bundle: .module),
                    Int64(count)
                )
            }

            static func behind(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.chip.behind %lld", bundle: .module),
                    Int64(count)
                )
            }
        }

        enum Empty {
            static var notRepo: String { ModuleLocalization.localized("git.empty.not_repo", bundle: .module) }
            static var initRepository: String { ModuleLocalization.localized("git.empty.init_repo", bundle: .module) }
        }

        enum Action {
            static var sync: String { ModuleLocalization.localized("git.action.sync", bundle: .module) }
            static var commitAndSync: String { ModuleLocalization.localized("git.action.commit_and_sync", bundle: .module) }
            static var push: String { ModuleLocalization.localized("git.action.push", bundle: .module) }
            static var pull: String { ModuleLocalization.localized("git.action.pull", bundle: .module) }
            static var commitOnly: String { ModuleLocalization.localized("git.action.commit_only", bundle: .module) }
            static var resolveConflict: String { ModuleLocalization.localized("git.action.resolve_conflict", bundle: .module) }
            static var working: String { ModuleLocalization.localized("git.action.working", bundle: .module) }
        }

        enum Commit {
            static var placeholder: String { ModuleLocalization.localized("git.commit.placeholder", bundle: .module) }
            static var scopeAll: String { ModuleLocalization.localized("git.commit.scope_all", bundle: .module) }

            static func generatedFiles(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.commit.generated_files %lld", bundle: .module),
                    Int64(count)
                )
            }

            static func generatedDirectory(_ directory: String, _ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.commit.generated_directory %@ %lld", bundle: .module),
                    directory,
                    Int64(count)
                )
            }

            static func largeCommitTitle(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("git.commit.large_title %lld", bundle: .module),
                    Int64(count)
                )
            }

            static var largeCommitMessage: String {
                ModuleLocalization.localized("git.commit.large_message", bundle: .module)
            }

            static var aiTooltip: String { ModuleLocalization.localized("git.commit.ai_tooltip", bundle: .module) }
        }

        enum Job {
            static var initRepository: String { ModuleLocalization.localized("git.job.init", bundle: .module) }
            static var pull: String { ModuleLocalization.localized("git.job.pull", bundle: .module) }
            static var commit: String { ModuleLocalization.localized("git.job.commit", bundle: .module) }
            static var push: String { ModuleLocalization.localized("git.job.push", bundle: .module) }
            static var sync: String { ModuleLocalization.localized("git.job.sync", bundle: .module) }
            static var stage: String { ModuleLocalization.localized("git.job.stage", bundle: .module) }
        }

        enum Error {
            static var pullWithDirty: String { ModuleLocalization.localized("git.error.pull_with_dirty", bundle: .module) }
            static var noUpstream: String { ModuleLocalization.localized("git.error.no_upstream", bundle: .module) }
            static var conflict: String { ModuleLocalization.localized("git.error.conflict", bundle: .module) }
            static var emptyCommitMessage: String { ModuleLocalization.localized("git.error.empty_commit_message", bundle: .module) }
            static var cancelled: String { ModuleLocalization.localized("git.error.cancelled", bundle: .module) }
            static var executableNotFound: String { ModuleLocalization.localized("git.error.executable_not_found", bundle: .module) }
        }

        enum History {
            static var title: String { ModuleLocalization.localized("git.history.title", bundle: .module) }
            static var empty: String { ModuleLocalization.localized("git.history.empty", bundle: .module) }
        }
    }

    enum RemoteServer {
        static var connectServerMenu: String { ModuleLocalization.localized("remote_server.connect_server_menu", bundle: .module) }
        static var sheetTitle: String { ModuleLocalization.localized("remote_server.sheet.title", bundle: .module) }
        static var addressPrompt: String { ModuleLocalization.localized("remote_server.address_prompt", bundle: .module) }
        static var addressPlaceholder: String { ModuleLocalization.localized("remote_server.address_placeholder", bundle: .module) }
        static var supportedProtocols: String { ModuleLocalization.localized("remote_server.supported_protocols", bundle: .module) }
        static var ftpSecurityNotice: String { ModuleLocalization.localized("remote_server.ftp_security_notice", bundle: .module) }
        static var recentTitle: String { ModuleLocalization.localized("remote_server.recent_title", bundle: .module) }
        static var removeFromRecent: String { ModuleLocalization.localized("remote_server.remove_from_recent", bundle: .module) }
        static var connecting: String { ModuleLocalization.localized("remote_server.connecting", bundle: .module) }
        static var connect: String { ModuleLocalization.localized("remote_server.connect", bundle: .module) }
        static var disconnectedFromServer: String {
            ModuleLocalization.localized("remote_server.disconnected_from_server", bundle: .module)
        }

        enum Error {
            static var invalidURL: String { ModuleLocalization.localized("remote_server.error.invalid_url", bundle: .module) }
            static var timeout: String { ModuleLocalization.localized("remote_server.error.timeout", bundle: .module) }
            static var ambiguousNewVolumes: String { ModuleLocalization.localized("remote_server.error.ambiguous_new_volumes", bundle: .module) }
            static var sftpDeferred: String { ModuleLocalization.localized("remote_server.error.sftp_deferred", bundle: .module) }

            static func mountFailed(_ detail: String) -> String {
                ModuleLocalization.localized("remote_server.error.mount_failed \(detail)", bundle: .module)
            }

            static func unsupportedProtocol(_ scheme: String) -> String {
                ModuleLocalization.localized("remote_server.error.unsupported_protocol \(scheme)", bundle: .module)
            }
        }
    }

    enum Settings {
        static var windowTitle: String { ModuleLocalization.localized("settings.window_title", bundle: .module) }
        static var menuItem: String { ModuleLocalization.localized("settings.menu_item", bundle: .module) }

        enum Tab {
            static var general: String { ModuleLocalization.localized("settings.tab.general", bundle: .module) }
            static var snippets: String { ModuleLocalization.localized("settings.tab.snippets", bundle: .module) }
            static var preview: String { ModuleLocalization.localized("settings.tab.preview", bundle: .module) }
            static var shortcuts: String { ModuleLocalization.localized("settings.tab.shortcuts", bundle: .module) }
        }

        enum Shortcuts {
            static var globalToggle: String { ModuleLocalization.localized("settings.shortcut.global_toggle", bundle: .module) }
            static var globalToggleEnabled: String { ModuleLocalization.localized("settings.shortcut.global_toggle_enabled", bundle: .module) }
            static var globalToggleFooter: String { ModuleLocalization.localized("settings.shortcut.global_toggle_footer", bundle: .module) }
            static var reset: String { ModuleLocalization.localized("settings.shortcut.reset", bundle: .module) }
            static var clickToRecord: String { ModuleLocalization.localized("settings.shortcut.click_to_record", bundle: .module) }
            static var recordingHint: String { ModuleLocalization.localized("settings.shortcut.recording_hint", bundle: .module) }
            static var recordingPlaceholder: String { ModuleLocalization.localized("settings.shortcut.recording_placeholder", bundle: .module) }
            static var cheatSheet: String { ModuleLocalization.localized("settings.shortcut.cheat_sheet", bundle: .module) }
            static var closeDetachedPreview: String { ModuleLocalization.localized("settings.shortcut.close_detached_preview", bundle: .module) }
            static var newTab: String { ModuleLocalization.localized("settings.shortcut.new_tab", bundle: .module) }
            static var copyPath: String { ModuleLocalization.localized("settings.shortcut.copy_path", bundle: .module) }
            static var previewTextEdit: String { ModuleLocalization.localized("settings.shortcut.preview_text_edit", bundle: .module) }

            static func category(_ id: String) -> String {
                ModuleLocalization.localizedFromTable("settings.shortcuts.category.\(id)", bundle: .module)
            }
        }

        enum General {
            static var blankDoubleClick: String { ModuleLocalization.localized("settings.blank_double_click", bundle: .module) }
            static var blankActionParent: String { ModuleLocalization.localized("settings.blank_action.parent", bundle: .module) }
            static var blankActionTerminal: String { ModuleLocalization.localized("settings.blank_action.terminal", bundle: .module) }
            static var windowSnap: String { ModuleLocalization.localized("settings.window_snap", bundle: .module) }
            static var fileListRowHover: String { ModuleLocalization.localized("settings.file_list.row_hover_highlight", bundle: .module) }
            static var interfaceLanguage: String { ModuleLocalization.localized("settings.general.interface_language", bundle: .module) }
            static var interfaceLanguageFooter: String { ModuleLocalization.localized("settings.general.interface_language_footer", bundle: .module) }
        }

        enum DefaultViewer {
            static var title: String { ModuleLocalization.localized("settings.default_viewer.title", bundle: .module) }
            static var current: String { ModuleLocalization.localized("settings.default_viewer.current", bundle: .module) }
            static var set: String { ModuleLocalization.localized("settings.default_viewer.set", bundle: .module) }
            static var restoreFinder: String { ModuleLocalization.localized("settings.default_viewer.restore_finder", bundle: .module) }
            static var restartHint: String { ModuleLocalization.localized("settings.default_viewer.restart_hint", bundle: .module) }
            static var setSuccess: String { ModuleLocalization.localized("settings.default_viewer.set_success", bundle: .module) }
            static var restoreSuccess: String { ModuleLocalization.localized("settings.default_viewer.restore_success", bundle: .module) }
        }

        enum Git {
            static var title: String { ModuleLocalization.localized("settings.git.title", bundle: .module) }
            static var executable: String { ModuleLocalization.localized("settings.git.executable", bundle: .module) }
            static var version: String { ModuleLocalization.localized("settings.git.version", bundle: .module) }
            static var choose: String { ModuleLocalization.localized("settings.git.choose", bundle: .module) }
            static var reset: String { ModuleLocalization.localized("settings.git.reset", bundle: .module) }
            static var footer: String { ModuleLocalization.localized("settings.git.footer", bundle: .module) }
            static var notFound: String { ModuleLocalization.localized("settings.git.not_found", bundle: .module) }
            static var invalidExecutable: String { ModuleLocalization.localized("settings.git.invalid_executable", bundle: .module) }
            static var choosePanelTitle: String { ModuleLocalization.localized("settings.git.choose_panel_title", bundle: .module) }
        }

        enum Snippets {
            static var displayMode: String { ModuleLocalization.localized("settings.snippets.display_mode", bundle: .module) }
            static var displayStandard: String { ModuleLocalization.localized("settings.snippets.display.standard", bundle: .module) }
            static var displayMinimal: String { ModuleLocalization.localized("settings.snippets.display.minimal", bundle: .module) }
            static var outputColorScheme: String { ModuleLocalization.localized("settings.snippets.output_color_scheme", bundle: .module) }
            static var outputColorDark: String { ModuleLocalization.localized("settings.snippets.output_color.dark", bundle: .module) }
            static var outputColorLight: String { ModuleLocalization.localized("settings.snippets.output_color.light", bundle: .module) }
            static var outputColorGray: String { ModuleLocalization.localized("settings.snippets.output_color.gray", bundle: .module) }
            static var pinRecent: String { ModuleLocalization.localized("settings.pin_recent_snippets", bundle: .module) }
            static var autoShowOutput: String { ModuleLocalization.localized("settings.auto_show_output", bundle: .module) }
            static var confirmDestructive: String { ModuleLocalization.localized("settings.confirm_destructive", bundle: .module) }
            static var recordingSection: String { ModuleLocalization.localized("settings.snippets.recording_section", bundle: .module) }
            static var recordingSectionFooter: String {
                ModuleLocalization.localized("settings.snippets.recording_section_footer", bundle: .module)
            }
            static var recordingGeneralizePaths: String {
                ModuleLocalization.localized("settings.snippets.recording_generalize_paths", bundle: .module)
            }
            static var recordingShowBanner: String {
                ModuleLocalization.localized("settings.snippets.recording_show_banner", bundle: .module)
            }

            static func jobConcurrencyLimit(_ count: Int) -> String {
                ModuleLocalization.localized("settings.job_concurrency_limit \(count)", bundle: .module)
            }
        }

        enum Preview {
            static var detachedBrowse: String { ModuleLocalization.localized("settings.preview.detached_browse", bundle: .module) }
            static var detachedBrowseFooter: String { ModuleLocalization.localized("settings.preview.detached_browse.footer", bundle: .module) }
            static var detachedBrowseToggle: String { ModuleLocalization.localized("settings.preview.detached_browse.toggle", bundle: .module) }
            static var codeLineNumbers: String { ModuleLocalization.localized("settings.preview.code_line_numbers", bundle: .module) }
            static var codeLineNumbersFooter: String { ModuleLocalization.localized("settings.preview.code_line_numbers.footer", bundle: .module) }
            static var codeLineNumbersToggle: String { ModuleLocalization.localized("settings.preview.code_line_numbers.toggle", bundle: .module) }
            static var noRulesHint: String { ModuleLocalization.localized("settings.preview.no_rules_hint", bundle: .module) }
            static var customTypes: String { ModuleLocalization.localized("settings.preview.custom_types", bundle: .module) }
            static var addRule: String { ModuleLocalization.localized("settings.preview.add_rule", bundle: .module) }
            static var exportRules: String { ModuleLocalization.localized("settings.preview.export_rules", bundle: .module) }
            static var importRules: String { ModuleLocalization.localized("settings.preview.import_rules", bundle: .module) }
            static var builtinCatalog: String { ModuleLocalization.localized("settings.preview.builtin_catalog", bundle: .module) }
            static var overrideBuiltin: String { ModuleLocalization.localized("settings.preview.override_builtin", bundle: .module) }
            static var disabled: String { ModuleLocalization.localized("settings.preview.disabled", bundle: .module) }
            static var addRuleTitle: String { ModuleLocalization.localized("settings.preview.add_rule_title", bundle: .module) }
            static var editRuleTitle: String { ModuleLocalization.localized("settings.preview.edit_rule_title", bundle: .module) }
            static var extensionsField: String { ModuleLocalization.localized("settings.preview.extensions_field", bundle: .module) }
            static var previewMode: String { ModuleLocalization.localized("settings.preview.preview_mode", bundle: .module) }
            static var overrideBuiltinToggle: String { ModuleLocalization.localized("settings.preview.override_builtin_toggle", bundle: .module) }
            static var enabledToggle: String { ModuleLocalization.localized("settings.preview.enabled_toggle", bundle: .module) }
            static var extensionlessLabel: String { ModuleLocalization.localized("settings.preview.extensionless_label", bundle: .module) }
            static var validationExtensions: String { ModuleLocalization.localized("settings.preview.validation_extensions", bundle: .module) }
            static var importExportTitle: String { ModuleLocalization.localized("settings.preview.import_export_title", bundle: .module) }
            static var exportPanelTitle: String { ModuleLocalization.localized("settings.preview.export_panel_title", bundle: .module) }
            static var importPanelTitle: String { ModuleLocalization.localized("settings.preview.import_panel_title", bundle: .module) }
            static var importMethodTitle: String { ModuleLocalization.localized("settings.preview.import_method_title", bundle: .module) }
            static var importMethodMessage: String { ModuleLocalization.localized("settings.preview.import_method_message", bundle: .module) }
            static var importMerge: String { ModuleLocalization.localized("settings.preview.import.merge", bundle: .module) }
            static var importReplace: String { ModuleLocalization.localized("settings.preview.import.replace", bundle: .module) }
            static var importComplete: String { ModuleLocalization.localized("settings.preview.import_complete", bundle: .module) }

            static func exportSuccess(_ count: Int) -> String {
                ModuleLocalization.localized("settings.preview.export_success \(count)", bundle: .module)
            }

            static func unavailableTitle(_ displayExtension: String) -> String {
                ModuleLocalization.localized("settings.preview.unavailable_title \(displayExtension)", bundle: .module)
            }

            static var unavailableHint: String { ModuleLocalization.localized("settings.preview.unavailable_hint", bundle: .module) }
            static var previewAsText: String { ModuleLocalization.localized("settings.preview.preview_as_text", bundle: .module) }
            static var previewQuickLook: String { ModuleLocalization.localized("settings.preview.preview_quicklook", bundle: .module) }
            static var openInSettings: String { ModuleLocalization.localized("settings.preview.open_in_settings", bundle: .module) }
            static var customize: String { ModuleLocalization.localized("settings.preview.customize", bundle: .module) }
            static var openBehavior: String { ModuleLocalization.localized("settings.preview.open_behavior", bundle: .module) }
            static var openBehaviorFooter: String { ModuleLocalization.localized("settings.preview.open_behavior.footer", bundle: .module) }
            static var doubleClick: String { ModuleLocalization.localized("settings.preview.double_click", bundle: .module) }
            static var archiveDoubleClick: String { ModuleLocalization.localized("settings.preview.archive_double_click", bundle: .module) }
            static var externalOpen: String { ModuleLocalization.localized("settings.preview.external_open", bundle: .module) }
            static var externalMultiImage: String { ModuleLocalization.localized("settings.preview.external_multi_image", bundle: .module) }

            enum DoubleClick {
                static var defaultApp: String { ModuleLocalization.localized("settings.preview.double_click.default_app", bundle: .module) }
                static var standalonePreview: String { ModuleLocalization.localized("settings.preview.double_click.standalone_preview", bundle: .module) }
                static var sidebarPreview: String { ModuleLocalization.localized("settings.preview.double_click.sidebar_preview", bundle: .module) }
            }

            enum ArchiveDoubleClick {
                static var extract: String { ModuleLocalization.localized("settings.preview.archive_double_click.extract", bundle: .module) }
                static var preview: String { ModuleLocalization.localized("settings.preview.archive_double_click.preview", bundle: .module) }
            }

            enum ExternalOpen {
                static var standaloneOnly: String { ModuleLocalization.localized("settings.preview.external_open.standalone_only", bundle: .module) }
                static var browserAndSelect: String { ModuleLocalization.localized("settings.preview.external_open.browser_and_select", bundle: .module) }
            }

            enum ExternalMultiImage {
                static var singleWindowWithStrip: String { ModuleLocalization.localized("settings.preview.external_multi_image.single_window_with_strip", bundle: .module) }
                static var oneWindowPerFile: String { ModuleLocalization.localized("settings.preview.external_multi_image.one_window_per_file", bundle: .module) }
            }

            enum HandlerGroup {
                static var title: String { ModuleLocalization.localized("settings.preview.handler_group.title", bundle: .module) }
                static var footer: String { ModuleLocalization.localized("settings.preview.handler_group.footer", bundle: .module) }
                static var restartHint: String { ModuleLocalization.localized("settings.preview.handler_group.restart_hint", bundle: .module) }
                static var image: String { ModuleLocalization.localized("settings.preview.handler_group.image", bundle: .module) }
                static var imageHint: String { ModuleLocalization.localized("settings.preview.handler_group.image.hint", bundle: .module) }
                static var pdf: String { ModuleLocalization.localized("settings.preview.handler_group.pdf", bundle: .module) }
                static var textAndCode: String { ModuleLocalization.localized("settings.preview.handler_group.text_and_code", bundle: .module) }
                static var media: String { ModuleLocalization.localized("settings.preview.handler_group.media", bundle: .module) }
                static var office: String { ModuleLocalization.localized("settings.preview.handler_group.office", bundle: .module) }

                static func currentHandler(_ name: String) -> String {
                    ModuleLocalization.localized("settings.preview.handler_group.current_handler \(name)", bundle: .module)
                }

                static func setSuccess(_ groupName: String) -> String {
                    ModuleLocalization.localized("settings.preview.handler_group.set_success \(groupName)", bundle: .module)
                }

                static func restoreSuccess(_ groupName: String) -> String {
                    ModuleLocalization.localized("settings.preview.handler_group.restore_success \(groupName)", bundle: .module)
                }
            }

            enum Mode {
                static var text: String { ModuleLocalization.localized("settings.preview.mode.text", bundle: .module) }
                static var markdown: String { ModuleLocalization.localized("settings.preview.mode.markdown", bundle: .module) }
                static var html: String { ModuleLocalization.localized("settings.preview.mode.html", bundle: .module) }
                static var quickLook: String { ModuleLocalization.localized("settings.preview.mode.quicklook", bundle: .module) }
                static var image: String { ModuleLocalization.localized("settings.preview.mode.image", bundle: .module) }
                static var pdf: String { ModuleLocalization.localized("settings.preview.mode.pdf", bundle: .module) }
                static var media: String { ModuleLocalization.localized("settings.preview.mode.media", bundle: .module) }
                static var archive: String { ModuleLocalization.localized("settings.preview.mode.archive", bundle: .module) }

                static var textDetail: String { ModuleLocalization.localized("settings.preview.mode.text.detail", bundle: .module) }
                static var markdownDetail: String { ModuleLocalization.localized("settings.preview.mode.markdown.detail", bundle: .module) }
                static var htmlDetail: String { ModuleLocalization.localized("settings.preview.mode.html.detail", bundle: .module) }
                static var quickLookDetail: String { ModuleLocalization.localized("settings.preview.mode.quicklook.detail", bundle: .module) }
                static var imageDetail: String { ModuleLocalization.localized("settings.preview.mode.image.detail", bundle: .module) }
                static var pdfDetail: String { ModuleLocalization.localized("settings.preview.mode.pdf.detail", bundle: .module) }
                static var mediaDetail: String { ModuleLocalization.localized("settings.preview.mode.media.detail", bundle: .module) }
                static var archiveDetail: String { ModuleLocalization.localized("settings.preview.mode.archive.detail", bundle: .module) }
            }
        }
    }

    enum Archive {
        static var jobCompress: String { ModuleLocalization.localized("archive.job.compress", bundle: .module) }
        static var jobExtract: String { ModuleLocalization.localized("archive.job.extract", bundle: .module) }
        static var hintNetworkSlow: String { ModuleLocalization.localized("archive.hint.network_slow", bundle: .module) }
        static var errorEncrypted: String { ModuleLocalization.localized("archive.error.encrypted", bundle: .module) }
        static var errorUnsupported: String { ModuleLocalization.localized("archive.error.unsupported", bundle: .module) }
        static var passwordTitle: String { ModuleLocalization.localized("archive.password.title", bundle: .module) }
        static var passwordPlaceholder: String { ModuleLocalization.localized("archive.password.placeholder", bundle: .module) }

        static func passwordMessage(_ archiveName: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("archive.password.message %@", bundle: .module),
                archiveName
            )
        }

        static func statusExtractingPartial(_ count: Int, _ archiveName: String, _ destinationName: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("archive.status.extracting_partial %lld %@ %@", bundle: .module),
                Int64(count),
                archiveName,
                destinationName
            )
        }

        static func statusCompressingItem(_ name: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("archive.status.compressing_item %@", bundle: .module),
                name
            )
        }

        static func statusCompressingCount(_ count: Int) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("archive.status.compressing_count %lld", bundle: .module),
                Int64(count)
            )
        }

        static func statusExtractingItem(_ archiveName: String, _ destinationName: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("archive.status.extracting_item %@ %@", bundle: .module),
                archiveName,
                destinationName
            )
        }

        static func statusExtractingCount(_ count: Int) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("archive.status.extracting_count %lld", bundle: .module),
                Int64(count)
            )
        }
    }

    enum Toolbar {
        static var showLeftPanel: String { ModuleLocalization.localized("toolbar.show_left_panel", bundle: .module) }
        static var hideLeftPanel: String { ModuleLocalization.localized("toolbar.hide_left_panel", bundle: .module) }
        static var newWindow: String { ModuleLocalization.localized("toolbar.new_window", bundle: .module) }
        static var newTab: String { ModuleLocalization.localized("toolbar.new_tab", bundle: .module) }
        static var showAllTabs: String { ModuleLocalization.localized("toolbar.show_all_tabs", bundle: .module) }
        static var showTabBar: String { ModuleLocalization.localized("toolbar.show_tab_bar", bundle: .module) }
        static var hideTabBar: String { ModuleLocalization.localized("toolbar.hide_tab_bar", bundle: .module) }
        static var tabBarCannotHideMultiple: String { ModuleLocalization.localized("toolbar.tab_bar.cannot_hide_multiple", bundle: .module) }
        static var tabBarUnavailable: String { ModuleLocalization.localized("toolbar.tab_bar.unavailable", bundle: .module) }
        static var newFolder: String { ModuleLocalization.localized("toolbar.new_folder", bundle: .module) }
        static var newFile: String { ModuleLocalization.localized("toolbar.new_file", bundle: .module) }
        static var recordOperations: String { ModuleLocalization.localized("toolbar.record_operations", bundle: .module) }
        static var recordOperationsActive: String { ModuleLocalization.localized("toolbar.record_operations_active", bundle: .module) }
        static var delete: String { ModuleLocalization.localized("toolbar.delete", bundle: .module) }
        static var showHiddenFiles: String { ModuleLocalization.localized("toolbar.show_hidden_files", bundle: .module) }
        static var hideHiddenFiles: String { ModuleLocalization.localized("toolbar.hide_hidden_files", bundle: .module) }
        static var listView: String { ModuleLocalization.localized("toolbar.list_view", bundle: .module) }
        static var thumbnailView: String { ModuleLocalization.localized("toolbar.thumbnail_view", bundle: .module) }
        static var panoramaMode: String { ModuleLocalization.localized("toolbar.panorama_mode", bundle: .module) }
        static var thumbnailSize: String { ModuleLocalization.localized("toolbar.thumbnail_size", bundle: .module) }
        static var browseSettings: String { ModuleLocalization.localized("toolbar.browse_settings", bundle: .module) }
        static var sort: String { ModuleLocalization.localized("toolbar.sort", bundle: .module) }
        static var viewPicker: String { ModuleLocalization.localized("toolbar.view_picker", bundle: .module) }
        static var autoFolderSize: String { ModuleLocalization.localized("toolbar.auto_folder_size", bundle: .module) }
        static var useIconPreview: String { ModuleLocalization.localized("toolbar.use_icon_preview", bundle: .module) }
        static var panoramaExpandAll: String { ModuleLocalization.localized("toolbar.panorama.expand_all", bundle: .module) }
        static var panoramaCollapseAll: String { ModuleLocalization.localized("toolbar.panorama.collapse_all", bundle: .module) }
        static var panoramaLayoutGrid: String { ModuleLocalization.localized("toolbar.panorama.layout_grid", bundle: .module) }
        static var panoramaLayoutPanorama: String { ModuleLocalization.localized("toolbar.panorama.layout_panorama", bundle: .module) }
        static var panoramaExpandDepth: String { ModuleLocalization.localized("toolbar.panorama.expand_depth", bundle: .module) }
        static var customize: String { ModuleLocalization.localized("toolbar.customize", bundle: .module) }
        static var customizeTitle: String { ModuleLocalization.localized("toolbar.customize.title", bundle: .module) }
        static var customizeHint: String { ModuleLocalization.localized("toolbar.customize.hint", bundle: .module) }
        static var customizeDone: String { ModuleLocalization.localized("toolbar.customize.done", bundle: .module) }
        static var customizeCancel: String { ModuleLocalization.localized("toolbar.customize.cancel", bundle: .module) }
        static var customizeReset: String { ModuleLocalization.localized("toolbar.customize.reset", bundle: .module) }
        static var addOpenApp: String { ModuleLocalization.localized("toolbar.customize.add_open_app", bundle: .module) }
        static var shortcutRemove: String { ModuleLocalization.localized("toolbar.shortcut.remove", bundle: .module) }
        static var openAppTitle: String { ModuleLocalization.localized("toolbar.open_app.title", bundle: .module) }
        static var openAppName: String { ModuleLocalization.localized("toolbar.open_app.name", bundle: .module) }
        static var openAppChoose: String { ModuleLocalization.localized("toolbar.open_app.choose", bundle: .module) }
        static var openAppChoosePrompt: String { ModuleLocalization.localized("toolbar.open_app.choose_prompt", bundle: .module) }
        static var openAppUseAppIcon: String { ModuleLocalization.localized("toolbar.open_app.use_app_icon", bundle: .module) }
        static var openAppAdd: String { ModuleLocalization.localized("toolbar.open_app.add", bundle: .module) }
        static var openAppSave: String { ModuleLocalization.localized("toolbar.open_app.save", bundle: .module) }
        static var openAppEdit: String { ModuleLocalization.localized("toolbar.open_app.edit", bundle: .module) }
        static var openAppEditTitle: String { ModuleLocalization.localized("toolbar.open_app.edit_title", bundle: .module) }
        static var openAppSelectionPolicy: String { ModuleLocalization.localized("toolbar.open_app.selection_policy", bundle: .module) }
        static var openAppSelectionRequire: String { ModuleLocalization.localized("toolbar.open_app.selection_require", bundle: .module) }
        static var openAppSelectionOptional: String { ModuleLocalization.localized("toolbar.open_app.selection_optional", bundle: .module) }
        static var openAppSelectionCurrentFolder: String { ModuleLocalization.localized("toolbar.open_app.selection_current_folder", bundle: .module) }
        static var openAppSelectionPolicyHelp: String { ModuleLocalization.localized("toolbar.open_app.selection_policy_help", bundle: .module) }

        static func openAppTooltip(_ appName: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("toolbar.open_app.tooltip", bundle: .module),
                appName
            )
        }

        enum Error {
            static var noSelection: String { ModuleLocalization.localized("toolbar.error.no_selection", bundle: .module) }
            static var appMissingTitle: String { ModuleLocalization.localized("toolbar.error.app_missing_title", bundle: .module) }
            static var shortcutMissingTitle: String {
                ModuleLocalization.localized("toolbar.error.shortcut_missing_title", bundle: .module)
            }

            static func appMissing(_ name: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("toolbar.error.app_missing", bundle: .module),
                    name
                )
            }

            static func shortcutMissing(_ name: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("toolbar.error.shortcut_missing", bundle: .module),
                    name
                )
            }
        }
    }

    enum OperationRecording {
        static var noSteps: String { ModuleLocalization.localized("operation_recording.no_steps", bundle: .module) }
        static var reviewTitle: String { ModuleLocalization.localized("operation_recording.review_title", bundle: .module) }
        static var generalizePaths: String { ModuleLocalization.localized("operation_recording.generalize_paths", bundle: .module) }
        static var previewLabel: String { ModuleLocalization.localized("operation_recording.preview_label", bundle: .module) }
        static var copyScript: String { ModuleLocalization.localized("operation_recording.copy_script", bundle: .module) }
        static var createSnippet: String { ModuleLocalization.localized("operation_recording.create_snippet", bundle: .module) }
        static var defaultSnippetName: String { ModuleLocalization.localized("operation_recording.default_snippet_name", bundle: .module) }
        static var shortClipboard: String { ModuleLocalization.localized("operation_recording.short.clipboard", bundle: .module) }
        static var shortCopy: String { ModuleLocalization.localized("operation_recording.short.copy", bundle: .module) }
        static var shortMove: String { ModuleLocalization.localized("operation_recording.short.move", bundle: .module) }
        static var shortDelete: String { ModuleLocalization.localized("operation_recording.short.delete", bundle: .module) }
        static var shortRename: String { ModuleLocalization.localized("operation_recording.short.rename", bundle: .module) }
        static var shortNewFolder: String { ModuleLocalization.localized("operation_recording.short.new_folder", bundle: .module) }
        static var shortNewFile: String { ModuleLocalization.localized("operation_recording.short.new_file", bundle: .module) }
        static var shortCompress: String { ModuleLocalization.localized("operation_recording.short.compress", bundle: .module) }
        static var shortExtract: String { ModuleLocalization.localized("operation_recording.short.extract", bundle: .module) }
        static var bannerStop: String { ModuleLocalization.localized("operation_recording.banner.stop", bundle: .module) }
        static var bannerDiscard: String { ModuleLocalization.localized("operation_recording.banner.discard", bundle: .module) }
        static var discardConfirmTitle: String { ModuleLocalization.localized("operation_recording.discard_confirm.title", bundle: .module) }
        static var discardConfirmMessage: String { ModuleLocalization.localized("operation_recording.discard_confirm.message", bundle: .module) }
        static var discarded: String { ModuleLocalization.localized("operation_recording.discarded", bundle: .module) }
        static var closeWhileRecordingTitle: String {
            ModuleLocalization.localized("operation_recording.close_while_recording.title", bundle: .module)
        }
        static var closeWhileRecordingMessage: String {
            ModuleLocalization.localized("operation_recording.close_while_recording.message", bundle: .module)
        }
        static var closeStopAndGenerate: String {
            ModuleLocalization.localized("operation_recording.close_while_recording.stop", bundle: .module)
        }
        static var closeDiscard: String {
            ModuleLocalization.localized("operation_recording.close_while_recording.discard", bundle: .module)
        }
        static var trashWarning: String {
            ModuleLocalization.localized("operation_recording.trash_warning", bundle: .module)
        }
        static var variablesTitle: String {
            ModuleLocalization.localized("operation_recording.variables_title", bundle: .module)
        }
        static var variablesFooter: String {
            ModuleLocalization.localized("operation_recording.variables_footer", bundle: .module)
        }
        static var testScript: String {
            ModuleLocalization.localized("operation_recording.test_script", bundle: .module)
        }

        enum Validation {
            static var passed: String { ModuleLocalization.localized("operation_recording.validation.passed", bundle: .module) }
            static var emptyScript: String { ModuleLocalization.localized("operation_recording.validation.empty", bundle: .module) }
            static var invalidShell: String { ModuleLocalization.localized("operation_recording.validation.invalid_shell", bundle: .module) }

            static func unsupportedVariable(_ token: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("operation_recording.validation.unsupported_variable", bundle: .module),
                    token
                )
            }

            static func variableExpansion(_ message: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("operation_recording.validation.variable_expansion", bundle: .module),
                    message
                )
            }

            static func shellSyntax(_ message: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("operation_recording.validation.shell_syntax", bundle: .module),
                    message
                )
            }
        }

        enum Security {
            static var rmRf: String { ModuleLocalization.localized("operation_recording.security.rm_rf", bundle: .module) }
            static var rmR: String { ModuleLocalization.localized("operation_recording.security.rm_r", bundle: .module) }
            static var rm: String { ModuleLocalization.localized("operation_recording.security.rm", bundle: .module) }
            static var mv: String { ModuleLocalization.localized("operation_recording.security.mv", bundle: .module) }
            static var mkfs: String { ModuleLocalization.localized("operation_recording.security.mkfs", bundle: .module) }
            static var dd: String { ModuleLocalization.localized("operation_recording.security.dd", bundle: .module) }
            static var sudo: String { ModuleLocalization.localized("operation_recording.security.sudo", bundle: .module) }
            static var eval: String { ModuleLocalization.localized("operation_recording.security.eval", bundle: .module) }
            static var chmod777: String { ModuleLocalization.localized("operation_recording.security.chmod_777", bundle: .module) }
            static var chmod777Recursive: String {
                ModuleLocalization.localized("operation_recording.security.chmod_777_recursive", bundle: .module)
            }
            static var writeDev: String { ModuleLocalization.localized("operation_recording.security.write_dev", bundle: .module) }
            static var curlPipe: String { ModuleLocalization.localized("operation_recording.security.curl_pipe", bundle: .module) }
            static var wgetPipe: String { ModuleLocalization.localized("operation_recording.security.wget_pipe", bundle: .module) }
        }

        static func scopeSuggestion(_ scopeLabel: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("operation_recording.scope_suggestion", bundle: .module),
                scopeLabel
            )
        }

        static func reviewSubtitle(_ stepCount: Int, recordedAt: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return String(
                format: ModuleLocalization.localizedFromTable("operation_recording.review_subtitle", bundle: .module),
                stepCount,
                formatter.string(from: recordedAt)
            )
        }

        static func scriptCopied(_ stepCount: Int) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("operation_recording.script_copied", bundle: .module),
                stepCount
            )
        }

        static func snippetSaved(_ name: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("operation_recording.snippet_saved", bundle: .module),
                name
            )
        }

        static func recordingName(_ summary: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("operation_recording.recording_name", bundle: .module),
                summary
            )
        }

        static func stepCopy(_ count: Int) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.copy", bundle: .module), count)
        }

        static func stepCut(_ count: Int) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.cut", bundle: .module), count)
        }

        static func stepPasteCopy(_ count: Int, _ destination: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.paste_copy", bundle: .module), count, destination)
        }

        static func stepPasteMove(_ count: Int, _ destination: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.paste_move", bundle: .module), count, destination)
        }

        static func stepDragCopy(_ count: Int, _ destination: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.drag_copy", bundle: .module), count, destination)
        }

        static func stepDragMove(_ count: Int, _ destination: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.drag_move", bundle: .module), count, destination)
        }

        static func stepTrash(_ count: Int) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.trash", bundle: .module), count)
        }

        static func stepDeleteImmediately(_ count: Int) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.delete_immediately", bundle: .module), count)
        }

        static func stepRename(_ newName: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.rename", bundle: .module), newName)
        }

        static func stepCreateDirectory(_ name: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.create_directory", bundle: .module), name)
        }

        static func stepCreateFile(_ name: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.create_file", bundle: .module), name)
        }

        static func stepCompress(_ count: Int, _ archiveName: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.compress", bundle: .module), count, archiveName)
        }

        static func stepExtract(_ archiveName: String, _ destinationName: String) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.step.extract", bundle: .module), archiveName, destinationName)
        }

        static func bannerMessage(_ stepCount: Int) -> String {
            String(format: ModuleLocalization.localizedFromTable("operation_recording.banner.message", bundle: .module), stepCount)
        }
    }

    enum Search {
        static var prompt: String { ModuleLocalization.localized("search.prompt", bundle: .module) }
        static var focus: String { ModuleLocalization.localized("search.focus", bundle: .module) }
        static var quickSearch: String { ModuleLocalization.localized("search.quick_search", bundle: .module) }
        static var closeQuickSearch: String { ModuleLocalization.localized("search.close_quick_search", bundle: .module) }
        static var modeFilename: String { ModuleLocalization.localized("search.mode.filename", bundle: .module) }
        static var modeContent: String { ModuleLocalization.localized("search.mode.content", bundle: .module) }
        static var contentPrompt: String { ModuleLocalization.localized("search.content_prompt", bundle: .module) }
        static var contentNoResults: String { ModuleLocalization.localized("search.content_no_results", bundle: .module) }
        static var contentTruncated: String { ModuleLocalization.localized("search.content_truncated", bundle: .module) }
        static var contentCancelled: String { ModuleLocalization.localized("search.content_cancelled", bundle: .module) }
        static var contentNextMatch: String { ModuleLocalization.localized("search.content_next_match", bundle: .module) }
        static var findInFolder: String { ModuleLocalization.localized("search.content_find_in_folder", bundle: .module) }
        static var filterTitle: String { ModuleLocalization.localized("search.filter.title", bundle: .module) }
        static var filterInclude: String { ModuleLocalization.localized("search.filter.include", bundle: .module) }
        static var filterExclude: String { ModuleLocalization.localized("search.filter.exclude", bundle: .module) }
        static var filterSubdirectories: String { ModuleLocalization.localized("search.filter.subdirectories", bundle: .module) }
        static var filterCaseSensitive: String { ModuleLocalization.localized("search.filter.case_sensitive", bundle: .module) }
        static var filterReset: String { ModuleLocalization.localized("search.filter.reset", bundle: .module) }
        static var filterIncludePlaceholder: String { ModuleLocalization.localized("search.filter.include_placeholder", bundle: .module) }
        static var filterExcludePlaceholder: String { ModuleLocalization.localized("search.filter.exclude_placeholder", bundle: .module) }

        static func contentSummaryFiles(_ count: Int) -> String {
            String(format: ModuleLocalization.localized("search.content_summary.files", bundle: .module), count)
        }

        static func contentSummaryMatches(_ count: Int) -> String {
            String(format: ModuleLocalization.localized("search.content_summary.matches", bundle: .module), count)
        }

        static func contentSummaryElapsed(_ seconds: TimeInterval) -> String {
            String(format: ModuleLocalization.localized("search.content_summary.elapsed", bundle: .module), seconds)
        }

        static func contentSummaryPosition(_ current: Int, _ total: Int) -> String {
            String(format: ModuleLocalization.localized("search.content_summary.position", bundle: .module), current, total)
        }

        static func contentProgress(scanned: Int, total: Int, matches: Int) -> String {
            String(format: ModuleLocalization.localized("search.content_progress", bundle: .module), scanned, total, matches)
        }

        static func contentSearchingMatches(_ matches: Int) -> String {
            String(format: ModuleLocalization.localized("search.content_searching", bundle: .module), matches)
        }
    }

    enum Pathbar {
        static var clear: String { ModuleLocalization.localized("pathbar.clear", bundle: .module) }
        static var selectAll: String { ModuleLocalization.localized("pathbar.select_all", bundle: .module) }
        static var commit: String { ModuleLocalization.localized("pathbar.commit", bundle: .module) }
        static var edit: String { ModuleLocalization.localized("pathbar.edit", bundle: .module) }
        static var subdirs: String { ModuleLocalization.localized("pathbar.subdirs", bundle: .module) }
        static var noSubdirs: String { ModuleLocalization.localized("pathbar.no_subdirs", bundle: .module) }
        static var parent: String { ModuleLocalization.localized("pathbar.parent", bundle: .module) }
        static var back: String { ModuleLocalization.localized("pathbar.back", bundle: .module) }
        static var forward: String { ModuleLocalization.localized("pathbar.forward", bundle: .module) }
        static var history: String { ModuleLocalization.localized("pathbar.history", bundle: .module) }
    }

    enum Dialog {
        static var create: String { ModuleLocalization.localized("dialog.create", bundle: .module) }
        static var newFolderTitle: String { ModuleLocalization.localized("dialog.new_folder_title", bundle: .module) }
        static var newFolderMessage: String { ModuleLocalization.localized("dialog.new_folder_message", bundle: .module) }
        static var newFileTitle: String { ModuleLocalization.localized("dialog.new_file_title", bundle: .module) }
        static var newFileMessage: String { ModuleLocalization.localized("dialog.new_file_message", bundle: .module) }
        static var folderNamePlaceholder: String { ModuleLocalization.localized("dialog.folder_name_placeholder", bundle: .module) }
        static var fileNamePlaceholder: String { ModuleLocalization.localized("dialog.file_name_placeholder", bundle: .module) }
        static var cannotCreateFile: String { ModuleLocalization.localized("dialog.cannot_create_file", bundle: .module) }
        static var cannotCreateFileMessage: String { ModuleLocalization.localized("dialog.cannot_create_file_message", bundle: .module) }
    }

    enum File {
        static var defaultNewFileName: String { ModuleLocalization.localized("file.default_new_name", bundle: .module) }
        static var pastedImageBaseName: String { ModuleLocalization.localized("file.pasted_image_base", bundle: .module) }
        static var pastedImageFileName: String { ModuleLocalization.localized("file.pasted_image_name", bundle: .module) }
        static var pastedTextFileName: String { ModuleLocalization.localized("file.pasted_text_name", bundle: .module) }
        static var pastedMarkdownFileName: String { ModuleLocalization.localized("file.pasted_markdown_name", bundle: .module) }
        static var pasteCreatingFromClipboard: String {
            ModuleLocalization.localized("file.paste_creating_from_clipboard", bundle: .module)
        }
        static func pasteProgress(_ completed: Int, _ total: Int) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("file.paste_progress", bundle: .module),
                completed,
                total
            )
        }
        static func pasteProgressWithName(_ completed: Int, _ total: Int, _ name: String) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("file.paste_progress_with_name", bundle: .module),
                completed,
                total,
                name
            )
        }
    }

    enum Sort {
        static var nameAscending: String { ModuleLocalization.localized("sort.name_ascending", bundle: .module) }
        static var nameDescending: String { ModuleLocalization.localized("sort.name_descending", bundle: .module) }
        static var dateNewest: String { ModuleLocalization.localized("sort.date_newest", bundle: .module) }
        static var dateOldest: String { ModuleLocalization.localized("sort.date_oldest", bundle: .module) }
        static var sizeSmallest: String { ModuleLocalization.localized("sort.size_smallest", bundle: .module) }
        static var sizeLargest: String { ModuleLocalization.localized("sort.size_largest", bundle: .module) }
    }

    enum Panorama {
        static var collapseFolder: String { ModuleLocalization.localized("panorama.collapse_folder", bundle: .module) }
        static var expandFolder: String { ModuleLocalization.localized("panorama.expand_folder", bundle: .module) }
        static var folderKind: String { ModuleLocalization.localized("panorama.folder_kind", bundle: .module) }
        static var loading: String { ModuleLocalization.localized("panorama.loading", bundle: .module) }

        static func itemCount(_ count: Int) -> String {
            String(
                format: ModuleLocalization.localizedFromTable("panorama.item_count %lld", bundle: .module),
                Int64(count)
            )
        }

        static var expandDepthAutomatic: String { ModuleLocalization.localized("panorama.expand_depth.automatic", bundle: .module) }
        static var expandDepth2: String { ModuleLocalization.localized("panorama.expand_depth.depth2", bundle: .module) }
        static var expandDepth5: String { ModuleLocalization.localized("panorama.expand_depth.depth5", bundle: .module) }
        static var expandDepthUnlimited: String { ModuleLocalization.localized("panorama.expand_depth.unlimited", bundle: .module) }
    }

    enum Permission {
        enum FullDiskAccess {
            static var title: String { ModuleLocalization.localized("permission.fda.title", bundle: .module) }
            static var message: String { ModuleLocalization.localized("permission.fda.message", bundle: .module) }
            static var step1: String { ModuleLocalization.localized("permission.fda.step1", bundle: .module) }
            static var step3: String { ModuleLocalization.localized("permission.fda.step3", bundle: .module) }
            static var detected: String { ModuleLocalization.localized("permission.fda.detected", bundle: .module) }
            static var notDetected: String { ModuleLocalization.localized("permission.fda.not_detected", bundle: .module) }
            static var later: String { ModuleLocalization.localized("permission.fda.later", bundle: .module) }
            static var openSettings: String { ModuleLocalization.localized("permission.fda.open_settings", bundle: .module) }
            static var restartApp: String { ModuleLocalization.localized("permission.fda.restart_app", bundle: .module) }

            static func step2(_ appName: String) -> String {
                ModuleLocalization.localized("permission.fda.step2 \(appName)", bundle: .module)
            }
        }

        enum Automation {
            static var title: String { ModuleLocalization.localized("permission.automation.title", bundle: .module) }
            static var message: String { ModuleLocalization.localized("permission.automation.message", bundle: .module) }
            static var openSettings: String { ModuleLocalization.localized("permission.automation.open_settings", bundle: .module) }
        }
    }

    enum Alert {
        static var operationFailed: String { ModuleLocalization.localized("alert.operation_failed", bundle: .module) }
        static var moveBlockedTitle: String { ModuleLocalization.localized("alert.move_blocked.title", bundle: .module) }
        static var emptyTrashTitle: String { ModuleLocalization.localized("alert.empty_trash.title", bundle: .module) }
        static var emptyTrashMessage: String { ModuleLocalization.localized("alert.empty_trash.message", bundle: .module) }
        static var putBackFailedTitle: String { ModuleLocalization.localized("alert.put_back_failed.title", bundle: .module) }
        static var deleteToTrashMessage: String { ModuleLocalization.localized("alert.delete_to_trash.message", bundle: .module) }
        static var deleteImmediatelyMessage: String { ModuleLocalization.localized("alert.delete_immediately.message", bundle: .module) }
        static func openWithChooseApp(_ name: String) -> String {
            ModuleLocalization.localized("alert.open_with.choose_app \(name)", bundle: .module)
        }

        static var openWithPrompt: String { ModuleLocalization.localized("alert.open_with.prompt", bundle: .module) }

        static func putBackFailedSingle(_ name: String) -> String {
            ModuleLocalization.localized("alert.put_back_failed.single \(name)", bundle: .module)
        }

        static func putBackFailedMultiple(_ count: Int) -> String {
            ModuleLocalization.localized("alert.put_back_failed.multiple \(count)", bundle: .module)
        }

        static func deleteImmediatelySingle(_ name: String) -> String {
            ModuleLocalization.localized("alert.delete_immediately.single \(name)", bundle: .module)
        }

        static func deleteImmediatelyMultiple(_ count: Int) -> String {
            ModuleLocalization.localized("alert.delete_immediately.multiple \(count)", bundle: .module)
        }

        static func confirmDeleteSingle(_ name: String) -> String {
            ModuleLocalization.localized("alert.confirm_delete.single \(name)", bundle: .module)
        }

        static func confirmDeleteMultiple(_ count: Int) -> String {
            ModuleLocalization.localized("alert.confirm_delete.multiple \(count)", bundle: .module)
        }

        static func selectedItems(_ count: Int) -> String {
            ModuleLocalization.localized("alert.selected_items \(count)", bundle: .module)
        }

        static func moveBlockedMessage(_ reason: FavoritePathNormalization.MoveBlockReason) -> String {
            switch reason {
            case .sourceMissing:
                return ModuleLocalization.localized("alert.move_blocked.source_missing", bundle: .module)
            case .destinationUnavailable:
                return ModuleLocalization.localized("alert.move_blocked.destination_unavailable", bundle: .module)
            case .destinationNotDirectory:
                return ModuleLocalization.localized("alert.move_blocked.destination_not_directory", bundle: .module)
            case .sameLocation:
                return ModuleLocalization.localized("alert.move_blocked.same_location", bundle: .module)
            case .destinationInsideSource:
                return ModuleLocalization.localized("alert.move_blocked.destination_inside_source", bundle: .module)
            case .alreadyInDestination:
                return ModuleLocalization.localized("alert.move_blocked.already_in_destination", bundle: .module)
            }
        }
    }

    enum Preview {
        static var title: String { ModuleLocalization.localized("preview.title", bundle: .module) }
        static var emptyState: String { ModuleLocalization.localized("preview.empty_state", bundle: .module) }
        static var expand: String { ModuleLocalization.localized("preview.expand", bundle: .module) }
        static var collapse: String { ModuleLocalization.localized("preview.collapse", bundle: .module) }
        static var close: String { ModuleLocalization.localized("preview.close", bundle: .module) }
        static var focusWindow: String { ModuleLocalization.localized("preview.focus_window", bundle: .module) }
        static var dockBack: String { ModuleLocalization.localized("preview.dock_back", bundle: .module) }
        static var reattachTitle: String { ModuleLocalization.localized("preview.reattach.title", bundle: .module) }
        static var reattachMessage: String { ModuleLocalization.localized("preview.reattach.message", bundle: .module) }
        static var reattachConfirm: String { ModuleLocalization.localized("preview.reattach.confirm", bundle: .module) }
        static var previous: String { ModuleLocalization.localized("preview.previous", bundle: .module) }
        static var next: String { ModuleLocalization.localized("preview.next", bundle: .module) }
        static var loading: String { ModuleLocalization.localized("preview.loading", bundle: .module) }
        static var errorLoading: String { ModuleLocalization.localized("preview.error_loading", bundle: .module) }
        static var notAvailable: String { ModuleLocalization.localized("preview.not_available", bundle: .module) }
        static var sessionClosed: String { ModuleLocalization.localized("preview.session_closed", bundle: .module) }
        static var saveFailedTitle: String { ModuleLocalization.localized("preview.save_failed_title", bundle: .module) }
        static var archiveTruncated: String { ModuleLocalization.localized("preview.archive_truncated", bundle: .module) }

        enum Save {
            static func overwriteConfirm(_ fileName: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("preview.save.overwrite_confirm", bundle: .module),
                    fileName
                )
            }
        }

        enum TextEdit {
            static var edit: String { ModuleLocalization.localized("preview.text_edit.edit", bundle: .module) }
            static var save: String { ModuleLocalization.localized("preview.text_edit.save", bundle: .module) }
            static var revert: String { ModuleLocalization.localized("preview.text_edit.discard", bundle: .module) }
            static var saveConfirmTitle: String {
                ModuleLocalization.localized("preview.text_edit.save_confirm_title", bundle: .module)
            }
            static var discardConfirmTitle: String {
                ModuleLocalization.localized("preview.text_edit.discard_confirm_title", bundle: .module)
            }
            static var unsavedTitle: String {
                ModuleLocalization.localized("preview.text_edit.unsaved_title", bundle: .module)
            }
            static var tooLarge: String { ModuleLocalization.localized("preview.text_edit.too_large", bundle: .module) }
            static var notWritable: String {
                ModuleLocalization.localized("preview.text_edit.not_writable", bundle: .module)
            }
            static var saveButton: String { ModuleLocalization.localized("preview.text_edit.save", bundle: .module) }
            static var cancelButton: String { ModuleLocalization.localized("preview.text_edit.cancel", bundle: .module) }
            static var discardButton: String { ModuleLocalization.localized("preview.text_edit.discard", bundle: .module) }
            static var dontSaveButton: String { ModuleLocalization.localized("preview.text_edit.dont_save", bundle: .module) }

            static func saveConfirmMessage(_ fileName: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable(
                        "preview.text_edit.save_confirm_message %@",
                        bundle: .module
                    ),
                    fileName
                )
            }

            static func discardConfirmMessage(_ fileName: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable(
                        "preview.text_edit.discard_confirm_message %@",
                        bundle: .module
                    ),
                    fileName
                )
            }

            static func unsavedMessage(_ fileName: String) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable(
                        "preview.text_edit.unsaved_message %@",
                        bundle: .module
                    ),
                    fileName
                )
            }

            static func denialTooltip(for reason: PreviewTextEditDenialReason) -> String? {
                switch reason {
                case .contentTruncated:
                    return tooLarge
                case .notWritable:
                    return notWritable
                default:
                    return nil
                }
            }
        }

        enum Markdown {
            static var mermaidRendering: String {
                ModuleLocalization.localized("preview.markdown.mermaid_rendering", bundle: .module)
            }
            static var mermaidRenderFailed: String {
                ModuleLocalization.localized("preview.markdown.mermaid_render_failed", bundle: .module)
            }
        }

        enum FolderInlineChild {
            static var openDirectory: String {
                ModuleLocalization.localized("preview.folder_inline.open_directory", bundle: .module)
            }
            static var previewFile: String {
                ModuleLocalization.localized("preview.folder_inline.preview_file", bundle: .module)
            }
        }

        enum Archive {
            static var loadingMore: String {
                ModuleLocalization.localized("preview.archive.loading_more", bundle: .module)
            }

            static func selectionCount(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("preview.archive.selection_count %lld", bundle: .module),
                    Int64(count)
                )
            }
        }

        enum Epub {
            static var noChapters: String { ModuleLocalization.localized("preview.epub.no_chapters", bundle: .module) }

            static func chapterProgress(_ current: Int, _ total: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable(
                        "preview.epub.chapter_progress %lld %lld",
                        bundle: .module
                    ),
                    Int64(current),
                    Int64(total)
                )
            }
        }

        enum Eml {
            static var from: String { ModuleLocalization.localized("preview.eml.from", bundle: .module) }
            static var to: String { ModuleLocalization.localized("preview.eml.to", bundle: .module) }
            static var cc: String { ModuleLocalization.localized("preview.eml.cc", bundle: .module) }
            static var subject: String { ModuleLocalization.localized("preview.eml.subject", bundle: .module) }
            static var date: String { ModuleLocalization.localized("preview.eml.date", bundle: .module) }
            static var attachments: String { ModuleLocalization.localized("preview.eml.attachments", bundle: .module) }
            static var emptyBody: String { ModuleLocalization.localized("preview.eml.empty_body", bundle: .module) }

            static func attachmentSize(_ bytes: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("preview.eml.attachment_size %lld", bundle: .module),
                    Int64(bytes)
                )
            }
        }

        enum Font {
            static var family: String { ModuleLocalization.localized("preview.font.family", bundle: .module) }
            static var style: String { ModuleLocalization.localized("preview.font.style", bundle: .module) }
            static var postScriptName: String { ModuleLocalization.localized("preview.font.post_script_name", bundle: .module) }
            static var version: String { ModuleLocalization.localized("preview.font.version", bundle: .module) }
            static var glyphs: String { ModuleLocalization.localized("preview.font.glyphs", bundle: .module) }
            static var copyright: String { ModuleLocalization.localized("preview.font.copyright", bundle: .module) }
            static var samples: String { ModuleLocalization.localized("preview.font.samples", bundle: .module) }
            static var registrationFailed: String { ModuleLocalization.localized("preview.font.registration_failed", bundle: .module) }

            static func pointSize(_ value: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("preview.font.point_size %lld", bundle: .module),
                    Int64(value)
                )
            }
        }

        enum Model3D {
            static var unitHint: String { ModuleLocalization.localized("preview.model3d.unit_hint", bundle: .module) }

            static func triangles(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("preview.model3d.triangles %lld", bundle: .module),
                    Int64(count)
                )
            }

            static func dimensions(_ width: Float, _ height: Float, _ depth: Float) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("preview.model3d.dimensions %.1f %.1f %.1f", bundle: .module),
                    width, height, depth
                )
            }
        }

        static func previewingInDetachedWindow(_ fileName: String) -> String {
            ModuleLocalization.localized("preview.detached_placeholder \(fileName)", bundle: .module)
        }

        enum Toolbar {
            static var zoomOut: String { ModuleLocalization.localized("preview.toolbar.zoom_out", bundle: .module) }
            static var zoomIn: String { ModuleLocalization.localized("preview.toolbar.zoom_in", bundle: .module) }
            static var zoomScale: String { ModuleLocalization.localized("preview.toolbar.zoom_scale", bundle: .module) }
            static var fitWindow: String { ModuleLocalization.localized("preview.toolbar.fit_window", bundle: .module) }
            static var actualSize: String { ModuleLocalization.localized("preview.toolbar.actual_size", bundle: .module) }
            static var moreActions: String { ModuleLocalization.localized("preview.toolbar.more_actions", bundle: .module) }
            static var previousPage: String { ModuleLocalization.localized("preview.toolbar.previous_page", bundle: .module) }
            static var nextPage: String { ModuleLocalization.localized("preview.toolbar.next_page", bundle: .module) }
            static var nextMatch: String { ModuleLocalization.localized("preview.toolbar.next_match", bundle: .module) }
            static var previousMatch: String { ModuleLocalization.localized("preview.toolbar.previous_match", bundle: .module) }
            static var clearSearch: String { ModuleLocalization.localized("preview.toolbar.clear_search", bundle: .module) }
            static var searchNoResults: String { ModuleLocalization.localized("preview.toolbar.search_no_results", bundle: .module) }
            static var reset: String { ModuleLocalization.localized("preview.toolbar.reset", bundle: .module) }
            static var pageNumber: String { ModuleLocalization.localized("preview.toolbar.page_number", bundle: .module) }
            static var jumpToPage: String { ModuleLocalization.localized("preview.toolbar.jump_to_page", bundle: .module) }
            static var searchInPreview: String { ModuleLocalization.localized("preview.toolbar.search_in_preview", bundle: .module) }
            static var searchPrompt: String { ModuleLocalization.localized("preview.toolbar.search_prompt", bundle: .module) }
            static var colorPicker: String { ModuleLocalization.localized("preview.toolbar.color_picker", bundle: .module) }
            static var copiedToClipboard: String { ModuleLocalization.localized("preview.toolbar.copied_to_clipboard", bundle: .module) }
            static var fitWidth: String { ModuleLocalization.localized("preview.toolbar.fit_width", bundle: .module) }
            static var fitPage: String { ModuleLocalization.localized("preview.toolbar.fit_page", bundle: .module) }
            static var zoomInOverall: String { ModuleLocalization.localized("preview.toolbar.zoom_in_overall", bundle: .module) }
            static var zoomOutOverall: String { ModuleLocalization.localized("preview.toolbar.zoom_out_overall", bundle: .module) }
            static var zoomInFont: String { ModuleLocalization.localized("preview.toolbar.zoom_in_font", bundle: .module) }
            static var zoomOutFont: String { ModuleLocalization.localized("preview.toolbar.zoom_out_font", bundle: .module) }
            static var fontSize: String { ModuleLocalization.localized("preview.toolbar.font_size", bundle: .module) }
            static var htmlPreview: String { ModuleLocalization.localized("preview.toolbar.html_preview", bundle: .module) }
            static var sourceMode: String { ModuleLocalization.localized("preview.toolbar.source_mode", bundle: .module) }
            static var copyAll: String { ModuleLocalization.localized("preview.toolbar.copy_all", bundle: .module) }
            static var jumpTop: String { ModuleLocalization.localized("preview.toolbar.jump_top", bundle: .module) }
            static var jumpBottom: String { ModuleLocalization.localized("preview.toolbar.jump_bottom", bundle: .module) }
            static var rotateCCW: String { ModuleLocalization.localized("preview.toolbar.rotate_ccw", bundle: .module) }
            static var rotateCW: String { ModuleLocalization.localized("preview.toolbar.rotate_cw", bundle: .module) }
            static var flipHorizontal: String { ModuleLocalization.localized("preview.toolbar.flip_horizontal", bundle: .module) }
            static var flipVertical: String { ModuleLocalization.localized("preview.toolbar.flip_vertical", bundle: .module) }
            static var undo: String { ModuleLocalization.localized("preview.toolbar.undo", bundle: .module) }
            static var resetView: String { ModuleLocalization.localized("preview.toolbar.reset_view", bundle: .module) }
            static var resize: String { ModuleLocalization.localized("preview.toolbar.resize", bundle: .module) }
            static var crop: String { ModuleLocalization.localized("preview.toolbar.crop", bundle: .module) }
            static var applyCrop: String { ModuleLocalization.localized("preview.toolbar.apply_crop", bundle: .module) }
            static var saveEdits: String { ModuleLocalization.localized("preview.toolbar.save_edits", bundle: .module) }
            static var copyModelInfo: String { ModuleLocalization.localized("preview.toolbar.copy_model_info", bundle: .module) }
            static var model3dWireframe: String { ModuleLocalization.localized("preview.toolbar.model3d_wireframe", bundle: .module) }
            static var model3dSolid: String { ModuleLocalization.localized("preview.toolbar.model3d_solid", bundle: .module) }
            static var model3dRotateUp: String { ModuleLocalization.localized("preview.toolbar.model3d_rotate_up", bundle: .module) }
            static var model3dRotateDown: String { ModuleLocalization.localized("preview.toolbar.model3d_rotate_down", bundle: .module) }
            static var copyImage: String { ModuleLocalization.localized("preview.toolbar.copy_image", bundle: .module) }
            static var openDefaultApp: String { ModuleLocalization.localized("preview.toolbar.open_default_app", bundle: .module) }
            static var play: String { ModuleLocalization.localized("preview.toolbar.play", bundle: .module) }
            static var runScript: String { ModuleLocalization.localized("preview.toolbar.run_script", bundle: .module) }
            static var pause: String { ModuleLocalization.localized("preview.toolbar.pause", bundle: .module) }
            static var mute: String { ModuleLocalization.localized("preview.toolbar.mute", bundle: .module) }
            static var unmute: String { ModuleLocalization.localized("preview.toolbar.unmute", bundle: .module) }
            static var refreshListing: String { ModuleLocalization.localized("preview.toolbar.refresh_listing", bundle: .module) }
            static var copyManifest: String { ModuleLocalization.localized("preview.toolbar.copy_manifest", bundle: .module) }
            static var archiveCollapse: String { ModuleLocalization.localized("preview.toolbar.archive_collapse", bundle: .module) }
            static var archiveExpand: String { ModuleLocalization.localized("preview.toolbar.archive_expand", bundle: .module) }
            static var extract: String { ModuleLocalization.localized("preview.toolbar.extract", bundle: .module) }
            static var extractTo: String { ModuleLocalization.localized("preview.toolbar.extract_to", bundle: .module) }
            static var extractSelected: String { ModuleLocalization.localized("preview.toolbar.extract_selected", bundle: .module) }
            static var extractSelectedTo: String { ModuleLocalization.localized("preview.toolbar.extract_selected_to", bundle: .module) }
            static var wrapDisable: String { ModuleLocalization.localized("preview.toolbar.wrap_disable", bundle: .module) }
            static var wrapEnable: String { ModuleLocalization.localized("preview.toolbar.wrap_enable", bundle: .module) }
            static var markdownToSource: String { ModuleLocalization.localized("preview.toolbar.markdown_to_source", bundle: .module) }
            static var markdownToPreview: String { ModuleLocalization.localized("preview.toolbar.markdown_to_preview", bundle: .module) }
            static var spreadsheetToQuickLook: String { ModuleLocalization.localized("preview.toolbar.spreadsheet_to_quicklook", bundle: .module) }
            static var spreadsheetToText: String { ModuleLocalization.localized("preview.toolbar.spreadsheet_to_text", bundle: .module) }
            static var wordDocumentToFormatted: String { ModuleLocalization.localized("preview.toolbar.word_document_to_formatted", bundle: .module) }
            static var wordDocumentToText: String { ModuleLocalization.localized("preview.toolbar.word_document_to_text", bundle: .module) }
            static var zoom: String { ModuleLocalization.localized("preview.toolbar.zoom", bundle: .module) }
            static var eyedropper: String { ModuleLocalization.localized("preview.toolbar.eyedropper", bundle: .module) }
            static var epubChapters: String { ModuleLocalization.localized("preview.toolbar.epub_chapters", bundle: .module) }
            static var epubPreviousChapter: String { ModuleLocalization.localized("preview.toolbar.epub_previous_chapter", bundle: .module) }
            static var epubNextChapter: String { ModuleLocalization.localized("preview.toolbar.epub_next_chapter", bundle: .module) }

            static func colorHex(_ hex: String) -> String {
                ModuleLocalization.localized("preview.toolbar.color_hex \(hex)", bundle: .module)
            }
        }

        enum Chrome {
            static var expand: String { ModuleLocalization.localized("preview.chrome.expand", bundle: .module) }
            static var collapse: String { ModuleLocalization.localized("preview.chrome.collapse", bundle: .module) }
            static var backToFolder: String { ModuleLocalization.localized("preview.chrome.back_to_folder", bundle: .module) }
            static var detach: String { ModuleLocalization.localized("preview.chrome.detach", bundle: .module) }
            static var dockBack: String { ModuleLocalization.localized("preview.chrome.dock_back", bundle: .module) }
            static var revealInFileList: String { ModuleLocalization.localized("preview.chrome.reveal_in_file_list", bundle: .module) }
            static var closeWindow: String { ModuleLocalization.localized("preview.chrome.close_window", bundle: .module) }
            static var closePreview: String { ModuleLocalization.localized("preview.chrome.close_preview", bundle: .module) }
        }

        enum Image {
            static var resizeTitle: String { ModuleLocalization.localized("preview.image.resize_title", bundle: .module) }
            static var resizeHint: String { ModuleLocalization.localized("preview.image.resize_hint", bundle: .module) }
            static var maintainAspect: String { ModuleLocalization.localized("preview.image.maintain_aspect", bundle: .module) }
            static var width: String { ModuleLocalization.localized("preview.image.width", bundle: .module) }
            static var height: String { ModuleLocalization.localized("preview.image.height", bundle: .module) }
            static var confirm: String { ModuleLocalization.localized("preview.image.confirm", bundle: .module) }
            static var validationEmpty: String { ModuleLocalization.localized("preview.image.validation.empty", bundle: .module) }
            static var validationInvalid: String { ModuleLocalization.localized("preview.image.validation.invalid", bundle: .module) }
            static var validationPositive: String { ModuleLocalization.localized("preview.image.validation.positive", bundle: .module) }
            static var validationMax: String { ModuleLocalization.localized("preview.image.validation.max", bundle: .module) }
        }
    }

    enum Snippets {
        static var title: String { ModuleLocalization.localized("snippets.title", bundle: .module) }

        enum Panel {
            static var expand: String { ModuleLocalization.localized("snippets.panel.expand", bundle: .module) }
            static var collapse: String { ModuleLocalization.localized("snippets.panel.collapse", bundle: .module) }
            static var new: String { ModuleLocalization.localized("snippets.panel.new", bundle: .module) }
            static var importExport: String { ModuleLocalization.localized("snippets.panel.import_export", bundle: .module) }
            static var close: String { ModuleLocalization.localized("snippets.panel.close", bundle: .module) }
            static var noMatch: String { ModuleLocalization.localized("snippets.panel.no_match", bundle: .module) }
            static var noResults: String { ModuleLocalization.localized("snippets.panel.no_results", bundle: .module) }
            static var searchPrompt: String { ModuleLocalization.localized("snippets.panel.search_prompt", bundle: .module) }
            static var executeInTerminal: String { ModuleLocalization.localized("snippets.panel.execute_in_terminal", bundle: .module) }
            static var exportSingle: String { ModuleLocalization.localized("snippets.panel.export_single", bundle: .module) }
            static var execute: String { ModuleLocalization.localized("snippets.panel.execute", bundle: .module) }
            static var importButton: String { ModuleLocalization.localized("snippets.panel.import_button", bundle: .module) }
            static var importAction: String { ModuleLocalization.localized("snippets.panel.import", bundle: .module) }
            static var exportAll: String { ModuleLocalization.localized("snippets.panel.export_all", bundle: .module) }
            static var importConflictTitle: String { ModuleLocalization.localized("snippets.panel.import_conflict_title", bundle: .module) }
            static var importStrategyLabel: String { ModuleLocalization.localized("snippets.panel.import_strategy_label", bundle: .module) }
            static var importDoneTitle: String { ModuleLocalization.localized("snippets.panel.import_done_title", bundle: .module) }
            static var importFailedTitle: String { ModuleLocalization.localized("snippets.panel.import_failed_title", bundle: .module) }

            static func importConflictMessage(_ count: Int) -> String {
                ModuleLocalization.localized("snippets.panel.import_conflict_message \(count)", bundle: .module)
            }

            static func importDoneMessage(imported: Int, skipped: Int) -> String {
                ModuleLocalization.localized("snippets.panel.import_done_message \(imported) \(skipped)", bundle: .module)
            }
        }

        enum Editor {
            static var newTitle: String { ModuleLocalization.localized("snippets.editor.new_title", bundle: .module) }
            static var editTitle: String { ModuleLocalization.localized("snippets.editor.edit_title", bundle: .module) }
            static var name: String { ModuleLocalization.localized("snippets.editor.name", bundle: .module) }
            static var scope: String { ModuleLocalization.localized("snippets.editor.scope", bundle: .module) }
            static var extensionsPlaceholder: String { ModuleLocalization.localized("snippets.editor.extensions_placeholder", bundle: .module) }
            static var pathsPlaceholder: String { ModuleLocalization.localized("snippets.editor.paths_placeholder", bundle: .module) }
            static var scriptType: String { ModuleLocalization.localized("snippets.editor.script_type", bundle: .module) }
            static var interpreter: String { ModuleLocalization.localized("snippets.editor.interpreter", bundle: .module) }
            static var useSystemTerminal: String { ModuleLocalization.localized("snippets.editor.use_system_terminal", bundle: .module) }
            static var terminalHint: String { ModuleLocalization.localized("snippets.editor.terminal_hint", bundle: .module) }
            static var content: String { ModuleLocalization.localized("snippets.editor.content", bundle: .module) }
            static var subtitle: String { ModuleLocalization.localized("snippets.editor.subtitle", bundle: .module) }
            static var sectionGeneral: String { ModuleLocalization.localized("snippets.editor.section_general", bundle: .module) }
            static var sectionScope: String { ModuleLocalization.localized("snippets.editor.section_scope", bundle: .module) }
            static var sectionExecution: String { ModuleLocalization.localized("snippets.editor.section_execution", bundle: .module) }
            static var sectionScript: String { ModuleLocalization.localized("snippets.editor.section_script", bundle: .module) }
            static var insertVariable: String { ModuleLocalization.localized("snippets.editor.insert_variable", bundle: .module) }
        }

        enum Variable {
            static var p: String { ModuleLocalization.localized("snippets.variable.p", bundle: .module) }
            static var d: String { ModuleLocalization.localized("snippets.variable.d", bundle: .module) }
            static var capitalP: String { ModuleLocalization.localized("snippets.variable.capital_p", bundle: .module) }
            static var f: String { ModuleLocalization.localized("snippets.variable.f", bundle: .module) }
            static var capitalF: String { ModuleLocalization.localized("snippets.variable.capital_f", bundle: .module) }
            static var n: String { ModuleLocalization.localized("snippets.variable.n", bundle: .module) }
            static var b: String { ModuleLocalization.localized("snippets.variable.b", bundle: .module) }
            static var e: String { ModuleLocalization.localized("snippets.variable.e", bundle: .module) }
            static var capitalN: String { ModuleLocalization.localized("snippets.variable.capital_n", bundle: .module) }
            static var q: String { ModuleLocalization.localized("snippets.variable.q", bundle: .module) }
            static var capitalQ: String { ModuleLocalization.localized("snippets.variable.capital_q", bundle: .module) }
            static var h: String { ModuleLocalization.localized("snippets.variable.h", bundle: .module) }
            static var u: String { ModuleLocalization.localized("snippets.variable.u", bundle: .module) }
            static var w: String { ModuleLocalization.localized("snippets.variable.w", bundle: .module) }
            static var date: String { ModuleLocalization.localized("snippets.variable.date", bundle: .module) }
            static var uuid: String { ModuleLocalization.localized("snippets.variable.uuid", bundle: .module) }
            static var ask: String { ModuleLocalization.localized("snippets.variable.ask", bundle: .module) }
            static var askNamed: String { ModuleLocalization.localized("snippets.variable.ask_named", bundle: .module) }
        }

        enum Ask {
            static var formTitle: String { ModuleLocalization.localized("snippets.ask.form_title", bundle: .module) }
            static var continueButton: String { ModuleLocalization.localized("snippets.ask.continue", bundle: .module) }

            static func forSnippet(_ name: String) -> String {
                ModuleLocalization.localized("snippets.ask.for_snippet \(name)", bundle: .module)
            }
        }

        enum VariableHelp {
            static var showReference: String { ModuleLocalization.localized("snippets.variable_help.show_reference", bundle: .module) }
            static var columnToken: String { ModuleLocalization.localized("snippets.variable_help.column_token", bundle: .module) }
            static var columnDescription: String {
                ModuleLocalization.localized("snippets.variable_help.column_description", bundle: .module)
            }
            static var footer: String { ModuleLocalization.localized("snippets.variable_help.footer", bundle: .module) }
        }

        enum Confirm {
            static var destructiveTitle: String { ModuleLocalization.localized("snippets.confirm.destructive_title", bundle: .module) }
            static var destructiveMessage: String { ModuleLocalization.localized("snippets.confirm.destructive_message", bundle: .module) }
            static var proceed: String { ModuleLocalization.localized("snippets.confirm.proceed", bundle: .module) }
        }

        enum Output {
            static var emptyHint: String { ModuleLocalization.localized("snippets.output.empty_hint", bundle: .module) }
            static var closeCurrent: String { ModuleLocalization.localized("snippets.output.close_current", bundle: .module) }
            static var closeOthers: String { ModuleLocalization.localized("snippets.output.close_others", bundle: .module) }
            static var closeAll: String { ModuleLocalization.localized("snippets.output.close_all", bundle: .module) }
            static var expand: String { ModuleLocalization.localized("snippets.output.expand", bundle: .module) }
            static var collapse: String { ModuleLocalization.localized("snippets.output.collapse", bundle: .module) }
            static var closePanel: String { ModuleLocalization.localized("snippets.output.close_panel", bundle: .module) }
            static var queued: String { ModuleLocalization.localized("snippets.output.queued", bundle: .module) }
            static var running: String { ModuleLocalization.localized("snippets.output.running", bundle: .module) }
            static var cancelled: String { ModuleLocalization.localized("snippets.output.cancelled", bundle: .module) }
            static var clear: String { ModuleLocalization.localized("snippets.output.clear", bundle: .module) }
            static var copy: String { ModuleLocalization.localized("snippets.output.copy", bundle: .module) }
            static var stop: String { ModuleLocalization.localized("snippets.output.stop", bundle: .module) }
            static var commandPlaceholder: String { ModuleLocalization.localized("snippets.output.command_placeholder", bundle: .module) }
            static var find: String { ModuleLocalization.localized("snippets.output.find", bundle: .module) }
            static var runHistoryCommand: String { ModuleLocalization.localized("snippets.output.run_history_command", bundle: .module) }
            static var noOutput: String { ModuleLocalization.localized("snippets.output.no_output", bundle: .module) }
            static var truncated: String { ModuleLocalization.localized("snippets.output.truncated", bundle: .module) }

            static func exitCode(_ code: Int) -> String {
                ModuleLocalization.localized("snippets.output.exit_code \(code)", bundle: .module)
            }

            static func commandFailed(_ code: Int) -> String {
                ModuleLocalization.localized("snippets.output.command_failed \(code)", bundle: .module)
            }

            static func completedWithExitCode(_ code: Int) -> String {
                ModuleLocalization.localized("snippets.output.completed_with_exit_code \(code)", bundle: .module)
            }

            static var statusBannerDismiss: String { ModuleLocalization.localized("snippets.output.status_banner.dismiss", bundle: .module) }
            static var statusBannerShowDetails: String { ModuleLocalization.localized("snippets.output.status_banner.show_details", bundle: .module) }
            static var statusBannerHideDetails: String { ModuleLocalization.localized("snippets.output.status_banner.hide_details", bundle: .module) }
            static var fullCommandTitle: String { ModuleLocalization.localized("snippets.output.full_command_title", bundle: .module) }
            static var expandCommand: String { ModuleLocalization.localized("snippets.output.expand_command", bundle: .module) }
            static var collapseCommand: String { ModuleLocalization.localized("snippets.output.collapse_command", bundle: .module) }
            static var runCommand: String { ModuleLocalization.localized("snippets.output.run_command", bundle: .module) }
        }

        enum Scope {
            static var anytime: String { ModuleLocalization.localized("snippets.scope.anytime", bundle: .module) }
            static var global: String { ModuleLocalization.localized("snippets.scope.global", bundle: .module) }
            static var filesOnly: String { ModuleLocalization.localized("snippets.scope.files_only", bundle: .module) }
            static var directoriesOnly: String { ModuleLocalization.localized("snippets.scope.directories_only", bundle: .module) }
            static var singleSelection: String { ModuleLocalization.localized("snippets.scope.single_selection", bundle: .module) }
            static var fileExtensions: String { ModuleLocalization.localized("snippets.scope.file_extensions", bundle: .module) }
            static var specificFiles: String { ModuleLocalization.localized("snippets.scope.specific_files", bundle: .module) }
        }

        enum ScopeDesc {
            static var anytime: String { ModuleLocalization.localized("snippets.scope.anytime.desc", bundle: .module) }
            static var global: String { ModuleLocalization.localized("snippets.scope.global.desc", bundle: .module) }
            static var filesOnly: String { ModuleLocalization.localized("snippets.scope.files_only.desc", bundle: .module) }
            static var directoriesOnly: String { ModuleLocalization.localized("snippets.scope.directories_only.desc", bundle: .module) }
            static var singleSelection: String { ModuleLocalization.localized("snippets.scope.single_selection.desc", bundle: .module) }
            static var fileExtensions: String { ModuleLocalization.localized("snippets.scope.file_extensions.desc", bundle: .module) }
            static var specificFiles: String { ModuleLocalization.localized("snippets.scope.specific_files.desc", bundle: .module) }
        }

        enum Strategy {
            static var skip: String { ModuleLocalization.localized("snippets.strategy.skip", bundle: .module) }
            static var overwrite: String { ModuleLocalization.localized("snippets.strategy.overwrite", bundle: .module) }
            static var rename: String { ModuleLocalization.localized("snippets.strategy.rename", bundle: .module) }
        }

        enum Badge {
            static var file: String { ModuleLocalization.localized("snippets.badge.file", bundle: .module) }
            static var directory: String { ModuleLocalization.localized("snippets.badge.directory", bundle: .module) }
            static var single: String { ModuleLocalization.localized("snippets.badge.single", bundle: .module) }
            static var path: String { ModuleLocalization.localized("snippets.badge.path", bundle: .module) }
        }

        enum Builtin {
            static var listDirectory: String { ModuleLocalization.localized("snippets.builtin.list_directory", bundle: .module) }
            static var showAttributes: String { ModuleLocalization.localized("snippets.builtin.show_attributes", bundle: .module) }
            static var openTerminal: String { ModuleLocalization.localized("snippets.builtin.open_terminal", bundle: .module) }
            static var copyPath: String { ModuleLocalization.localized("snippets.builtin.copy_path", bundle: .module) }
            static var openDefault: String { ModuleLocalization.localized("snippets.builtin.open_default", bundle: .module) }
            static var finderInfo: String { ModuleLocalization.localized("snippets.builtin.finder_info", bundle: .module) }
            static var openPDF: String { ModuleLocalization.localized("snippets.builtin.open_pdf", bundle: .module) }
        }

        enum Import {
            static var renameSuffix: String { ModuleLocalization.localized("snippets.import.rename_suffix", bundle: .module) }

            static func renameSuffix(counter: Int) -> String {
                ModuleLocalization.localized("snippets.import.rename_suffix \(counter)", bundle: .module)
            }
        }
    }

    enum Error {
        static var symlinkLoop: String { ModuleLocalization.localized("error.symlink_loop", bundle: .module) }
        static var noPermission: String { ModuleLocalization.localized("error.no_permission", bundle: .module) }
        static var directoryNotFound: String { ModuleLocalization.localized("error.directory_not_found", bundle: .module) }
        static var emptyName: String { ModuleLocalization.localized("error.empty_name", bundle: .module) }

        enum DefaultViewer {
            static var preferencesSync: String { ModuleLocalization.localized("error.default_viewer.preferences_sync", bundle: .module) }
            static var finderNotFound: String { ModuleLocalization.localized("error.default_viewer.finder_not_found", bundle: .module) }

            static func defaultsCommand(_ code: Int32) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("error.default_viewer.defaults_command %lld", bundle: .module),
                    Int64(code)
                )
            }

            static func launchServices(_ status: OSStatus) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("error.default_viewer.launch_services %lld", bundle: .module),
                    Int64(status)
                )
            }
        }

        enum DefaultPreviewHandler {
            static var preferencesSync: String { ModuleLocalization.localized("error.default_preview_handler.preferences_sync", bundle: .module) }

            static func defaultsCommand(_ code: Int32) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("error.default_preview_handler.defaults_command %lld", bundle: .module),
                    Int64(code)
                )
            }

            static func fallbackNotFound(_ bundleID: String) -> String {
                ModuleLocalization.localized("error.default_preview_handler.fallback_not_found \(bundleID)", bundle: .module)
            }

            static func launchServices(_ status: OSStatus) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("error.default_preview_handler.launch_services %lld", bundle: .module),
                    Int64(status)
                )
            }
        }

        enum SnippetImport {
            static var invalidFormat: String { ModuleLocalization.localized("error.snippet_import.invalid_format", bundle: .module) }
            static var unsupportedSchema: String { ModuleLocalization.localized("error.snippet_import.unsupported_schema", bundle: .module) }
            static var tooMany: String { ModuleLocalization.localized("error.snippet_import.too_many", bundle: .module) }
            static var emptyName: String { ModuleLocalization.localized("error.snippet_import.empty_name", bundle: .module) }
            static var emptyContent: String { ModuleLocalization.localized("error.snippet_import.empty_content", bundle: .module) }

            static func invalid(_ detail: String) -> String {
                ModuleLocalization.localized("error.snippet_import.invalid \(detail)", bundle: .module)
            }
        }

        enum SnippetExpansion {
            static var singleSelection: String { ModuleLocalization.localized("error.snippet_expansion.single_selection", bundle: .module) }
            static var requiresSelection: String { ModuleLocalization.localized("error.snippet_expansion.requires_selection", bundle: .module) }
            static var fileSelection: String { ModuleLocalization.localized("error.snippet_expansion.file_selection", bundle: .module) }
            static var filesInSelection: String { ModuleLocalization.localized("error.snippet_expansion.files_in_selection", bundle: .module) }
            static var noFiles: String { ModuleLocalization.localized("error.snippet_expansion.no_files", bundle: .module) }
        }

        enum SnippetAsk {
            static var emptyPrompt: String { ModuleLocalization.localized("error.snippet_ask.empty_prompt", bundle: .module) }
            static var unclosedBrace: String { ModuleLocalization.localized("error.snippet_ask.unclosed_brace", bundle: .module) }

            static func invalidId(_ id: String) -> String {
                ModuleLocalization.localized("error.snippet_ask.invalid_id \(id)", bundle: .module)
            }
        }

        enum Shell {
            static var timedOut: String { ModuleLocalization.localized("error.shell.timed_out", bundle: .module) }
        }

        enum Archive {
            static var emptyListing: String { ModuleLocalization.localized("error.archive.empty_listing", bundle: .module) }
            static var timedOut: String { ModuleLocalization.localized("error.archive.timed_out", bundle: .module) }
        }

        enum Epub {
            static var unzipFailed: String { ModuleLocalization.localized("error.epub.unzip_failed", bundle: .module) }
            static var containerNotFound: String { ModuleLocalization.localized("error.epub.container_not_found", bundle: .module) }
            static var opfNotFound: String { ModuleLocalization.localized("error.epub.opf_not_found", bundle: .module) }
            static var invalidOPF: String { ModuleLocalization.localized("error.epub.invalid_opf", bundle: .module) }
            static var emptySpine: String { ModuleLocalization.localized("error.epub.empty_spine", bundle: .module) }
        }

        enum Eml {
            static var emptyMessage: String { ModuleLocalization.localized("error.eml.empty_message", bundle: .module) }
            static var unreadableEncoding: String { ModuleLocalization.localized("error.eml.unreadable_encoding", bundle: .module) }
            static var invalidFormat: String { ModuleLocalization.localized("error.eml.invalid_format", bundle: .module) }
            static var emptyBody: String { ModuleLocalization.localized("error.eml.empty_body", bundle: .module) }
        }

        enum Font {
            static var unableToLoad: String { ModuleLocalization.localized("error.font.unable_to_load", bundle: .module) }
        }

        enum Model3D {
            static var unableToLoad: String { ModuleLocalization.localized("error.model3d.unable_to_load", bundle: .module) }
            static var emptyModel: String { ModuleLocalization.localized("error.model3d.empty_model", bundle: .module) }
            static var fileTooLarge: String { ModuleLocalization.localized("error.model3d.file_too_large", bundle: .module) }

            static func tooManyTriangles(_ count: Int) -> String {
                String(
                    format: ModuleLocalization.localizedFromTable("error.model3d.too_many_triangles %lld", bundle: .module),
                    Int64(count)
                )
            }
        }

        enum Image {
            static var unableToEncode: String { ModuleLocalization.localized("error.image.unable_to_encode", bundle: .module) }
            static var unableToWrite: String { ModuleLocalization.localized("error.image.unable_to_write", bundle: .module) }
        }
    }

    enum Info {
        static var kindFolder: String { ModuleLocalization.localized("info.kind.folder", bundle: .module) }
        static var kindFile: String { ModuleLocalization.localized("info.kind.file", bundle: .module) }
        static var yes: String { ModuleLocalization.localized("info.yes", bundle: .module) }
        static var no: String { ModuleLocalization.localized("info.no", bundle: .module) }
        static var kindFolderShort: String { ModuleLocalization.localized("info.kind.folder_short", bundle: .module) }
        static var kindFileShort: String { ModuleLocalization.localized("info.kind.file_short", bundle: .module) }
        static var accessReadable: String { ModuleLocalization.localized("info.access.readable", bundle: .module) }
        static var accessWritable: String { ModuleLocalization.localized("info.access.writable", bundle: .module) }
        static var accessExecutable: String { ModuleLocalization.localized("info.access.executable", bundle: .module) }
        static var accessLabel: String { ModuleLocalization.localized("info.access.label", bundle: .module) }
        static var hiddenLabel: String { ModuleLocalization.localized("info.hidden.label", bundle: .module) }
        static var pathLabel: String { ModuleLocalization.localized("info.path.label", bundle: .module) }
        static var ellipsis: String { ModuleLocalization.localized("info.ellipsis", bundle: .module) }

        static func kindExtensionFile(_ ext: String) -> String {
            ModuleLocalization.localized("info.kind.extension_file \(ext)", bundle: .module)
        }

        static func size(_ value: String) -> String {
            ModuleLocalization.localized("info.size \(value)", bundle: .module)
        }

        static func location(_ value: String) -> String {
            ModuleLocalization.localized("info.location \(value)", bundle: .module)
        }

        static func created(_ value: String) -> String {
            ModuleLocalization.localized("info.created \(value)", bundle: .module)
        }

        static func modified(_ value: String) -> String {
            ModuleLocalization.localized("info.modified \(value)", bundle: .module)
        }

        static func hidden(_ isHidden: Bool) -> String {
            ModuleLocalization.localized("info.hidden \(isHidden ? yes : no)", bundle: .module)
        }

        static func permissions(_ symbolic: String, _ octal: String) -> String {
            ModuleLocalization.localized("info.permissions \(symbolic) \(octal)", bundle: .module)
        }

        static func typeIdentifier(_ value: String) -> String {
            ModuleLocalization.localized("info.type_identifier \(value)", bundle: .module)
        }

        static func path(_ value: String) -> String {
            ModuleLocalization.localized("info.path \(value)", bundle: .module)
        }

        static func bulletItem(_ name: String, _ kind: String, _ size: String) -> String {
            ModuleLocalization.localized("info.bullet_item \(name) \(kind) \(size)", bundle: .module)
        }
    }

    enum Help {
        static var windowTitle: String { localizedFromTable("help.window_title") }
        static var cheatSheetMenu: String { localizedFromTable("help.cheat_sheet_menu") }
        static var subtitle: String { localizedFromTable("help.subtitle") }
        static var columnFeature: String { localizedFromTable("help.column.feature") }
        static var columnDescription: String { localizedFromTable("help.column.description") }
        static var columnShortcut: String { localizedFromTable("help.column.shortcut") }
        static var noShortcut: String { localizedFromTable("help.no_shortcut") }

        static func sectionTitle(_ sectionID: String) -> String {
            localizedFromTable("help.section.\(sectionID)")
        }

        static func entryName(_ entryID: String) -> String {
            localizedFromTable("help.entry.\(entryID).name")
        }

        static func entryDescription(_ entryID: String) -> String {
            localizedFromTable("help.entry.\(entryID).desc")
        }

        static func entryShortcut(_ entryID: String) -> String {
            localizedFromTable("help.entry.\(entryID).shortcut")
        }

        private static func localizedFromTable(_ key: String) -> String {
            ModuleLocalization.localizedFromTable(key, bundle: .module)
        }
    }

    enum CommandPalette {
        static var placeholder: String { localizedFromTable("command_palette.placeholder") }
        static var noResults: String { localizedFromTable("command_palette.no_results") }
        static var recentsSection: String { localizedFromTable("command_palette.recents_section") }
        static var commonSection: String { localizedFromTable("command_palette.common_section") }
        static var menuTitle: String { localizedFromTable("command_palette.menu_title") }
        static var snippetsSection: String { localizedFromTable("command_palette.snippets_section") }

        private static func localizedFromTable(_ key: String) -> String {
            ModuleLocalization.localizedFromTable(key, bundle: .module)
        }
    }
}
