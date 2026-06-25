import Foundation

struct HelpCheatSheetSection: Identifiable {
    let id: String
    let entries: [String]
}

enum HelpCheatSheetContent {
    static let sections: [HelpCheatSheetSection] = [
        HelpCheatSheetSection(id: "navigation", entries: [
            "file_list", "list_view", "thumbnail_view", "path_breadcrumb", "path_edit",
            "back_forward", "path_history", "quick_search", "global_search",
            "double_click_open", "blank_double_click", "drag_drop_open", "external_open",
        ]),
        HelpCheatSheetSection(id: "sidebar", entries: [
            "favorites", "locations", "devices", "trash", "toggle_left_panel",
        ]),
        HelpCheatSheetSection(id: "files", entries: [
            "open", "open_new_window", "open_with", "cut_copy_paste", "delete",
            "delete_immediately", "put_back", "empty_trash", "rename", "new_folder_file",
            "copy_name_path", "open_terminal", "show_info", "services", "add_favorite",
        ]),
        HelpCheatSheetSection(id: "preview", entries: [
            "file_preview", "text_code", "markdown_html", "image", "pdf", "media",
            "archive", "spreadsheet", "quick_look", "in_preview_search",
            "detach_preview", "preview_browser", "custom_preview_rules",
        ]),
        HelpCheatSheetSection(id: "snippets", entries: [
            "snippets_panel", "run_snippet", "scope", "variables",
            "create_edit", "import_export", "builtin_snippets",
        ]),
        HelpCheatSheetSection(id: "output", entries: [
            "output_panel", "job_tabs", "command_box", "command_history",
            "stop_task", "output_find", "copy_clear",
        ]),
        HelpCheatSheetSection(id: "layout", entries: [
            "toggle_right_panel", "panel_height", "panel_width", "window_snap", "multi_window",
        ]),
        HelpCheatSheetSection(id: "settings", entries: [
            "settings_general", "settings_snippets", "settings_preview", "default_file_manager",
        ]),
        HelpCheatSheetSection(id: "permissions", entries: [
            "full_disk_access", "automation",
        ]),
    ]
}
