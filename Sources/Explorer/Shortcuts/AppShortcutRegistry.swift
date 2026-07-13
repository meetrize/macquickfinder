import Foundation

enum AppShortcutCategory: String, CaseIterable, Identifiable {
    case global
    case navigation
    case panels
    case files
    case preview
    case output
    case system

    var id: String { rawValue }

    var title: String {
        L10n.Settings.Shortcuts.category(rawValue)
    }
}

struct AppShortcutEntry: Identifiable {
    let id: String
    let category: AppShortcutCategory
    let name: String
    let shortcut: String
    let isConfigurable: Bool

    init(
        id: String,
        category: AppShortcutCategory,
        helpEntryID: String,
        isConfigurable: Bool = false
    ) {
        self.id = id
        self.category = category
        self.name = L10n.Help.entryName(helpEntryID)
        self.shortcut = L10n.Help.entryShortcut(helpEntryID)
        self.isConfigurable = isConfigurable
    }

    init(
        id: String,
        category: AppShortcutCategory,
        name: String,
        shortcut: String,
        isConfigurable: Bool = false
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.shortcut = shortcut
        self.isConfigurable = isConfigurable
    }
}

enum AppShortcutRegistry {
    static let entries: [AppShortcutEntry] = [
        AppShortcutEntry(id: "focus_search", category: .navigation, helpEntryID: "global_search"),
        AppShortcutEntry(id: "find_in_folder", category: .navigation, helpEntryID: "content_search"),
        AppShortcutEntry(id: "back_forward", category: .navigation, helpEntryID: "back_forward"),
        AppShortcutEntry(
            id: "new_tab",
            category: .navigation,
            name: L10n.Toolbar.newTab,
            shortcut: ShortcutBinding.defaultNewTab.displayString,
            isConfigurable: true
        ),
        AppShortcutEntry(
            id: "show_all_tabs",
            category: .navigation,
            name: L10n.Toolbar.showAllTabs,
            shortcut: "⌘⇧\\"
        ),
        AppShortcutEntry(
            id: "cheat_sheet",
            category: .navigation,
            name: L10n.Settings.Shortcuts.cheatSheet,
            shortcut: "⌘?"
        ),
        AppShortcutEntry(
            id: "command_palette",
            category: .navigation,
            name: L10n.CommandPalette.menuTitle,
            shortcut: "⌘⇧P"
        ),
        AppShortcutEntry(id: "quick_search", category: .navigation, helpEntryID: "quick_search"),

        AppShortcutEntry(id: "toggle_left_panel", category: .panels, helpEntryID: "toggle_left_panel"),
        AppShortcutEntry(id: "toggle_right_panel", category: .panels, helpEntryID: "toggle_right_panel"),
        AppShortcutEntry(id: "snippets_panel", category: .panels, helpEntryID: "snippets_panel"),
        AppShortcutEntry(id: "output_panel", category: .panels, helpEntryID: "output_panel"),

        AppShortcutEntry(id: "cut_copy_paste", category: .files, helpEntryID: "cut_copy_paste"),
        AppShortcutEntry(id: "delete", category: .files, helpEntryID: "delete"),
        AppShortcutEntry(id: "open", category: .files, helpEntryID: "open"),
        AppShortcutEntry(id: "rename", category: .files, helpEntryID: "rename"),
        AppShortcutEntry(
            id: "copy_path",
            category: .files,
            name: L10n.Action.copyPaths,
            shortcut: ShortcutBinding.defaultCopyPath.displayString,
            isConfigurable: true
        ),

        AppShortcutEntry(id: "detach_preview", category: .preview, helpEntryID: "detach_preview"),
        AppShortcutEntry(
            id: "preview_text_edit",
            category: .preview,
            name: L10n.Settings.Shortcuts.previewTextEdit,
            shortcut: ShortcutBinding.defaultPreviewTextEdit.displayString,
            isConfigurable: true
        ),
        AppShortcutEntry(id: "preview_browser", category: .preview, helpEntryID: "preview_browser"),
        AppShortcutEntry(
            id: "previous_preview",
            category: .preview,
            name: L10n.Menu.previousPreview,
            shortcut: "←"
        ),
        AppShortcutEntry(
            id: "next_preview",
            category: .preview,
            name: L10n.Menu.nextPreview,
            shortcut: "→"
        ),
        AppShortcutEntry(
            id: "close_detached_preview",
            category: .preview,
            name: L10n.Settings.Shortcuts.closeDetachedPreview,
            shortcut: "Esc"
        ),

        AppShortcutEntry(id: "command_box", category: .output, helpEntryID: "command_box"),
        AppShortcutEntry(id: "command_history", category: .output, helpEntryID: "command_history"),
        AppShortcutEntry(id: "stop_task", category: .output, helpEntryID: "stop_task"),
        AppShortcutEntry(id: "output_find", category: .output, helpEntryID: "output_find"),

        AppShortcutEntry(id: "settings_general", category: .system, helpEntryID: "settings_general"),
    ]

    static func entries(for category: AppShortcutCategory) -> [AppShortcutEntry] {
        entries.filter { $0.category == category }
    }
}
