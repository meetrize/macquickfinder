import Foundation

/// FileList 模块本地化字符串访问层。
enum L10n {
    enum Column {
        static var name: String { ModuleLocalization.localized("column.name", bundle: .module) }
        static var type: String { ModuleLocalization.localized("column.type", bundle: .module) }
        static var size: String { ModuleLocalization.localized("column.size", bundle: .module) }
        static var dateModified: String { ModuleLocalization.localized("column.date_modified", bundle: .module) }
        static var dateCreated: String { ModuleLocalization.localized("column.date_created", bundle: .module) }
        static var comment: String { ModuleLocalization.localized("column.comment", bundle: .module) }
        static var tags: String { ModuleLocalization.localized("column.tags", bundle: .module) }
        static var moveLeft: String { ModuleLocalization.localized("column.move_left", bundle: .module) }
        static var moveRight: String { ModuleLocalization.localized("column.move_right", bundle: .module) }
    }

    enum Action {
        static var goBack: String { ModuleLocalization.localized("action.go_back", bundle: .module) }
        static var goUp: String { ModuleLocalization.localized("action.go_up", bundle: .module) }
        static var refresh: String { ModuleLocalization.localized("action.refresh", bundle: .module) }
        static var newFolder: String { ModuleLocalization.localized("action.new_folder", bundle: .module) }
        static var newFile: String { ModuleLocalization.localized("action.new_file", bundle: .module) }
        static var openTerminalHere: String { ModuleLocalization.localized("action.open_terminal_here", bundle: .module) }
        static var paste: String { ModuleLocalization.localized("action.paste", bundle: .module) }
        static var emptyTrash: String { ModuleLocalization.localized("action.empty_trash", bundle: .module) }
    }

    enum ViewMode {
        static var list: String { ModuleLocalization.localized("view_mode.list", bundle: .module) }
        static var thumbnail: String { ModuleLocalization.localized("view_mode.thumbnail", bundle: .module) }
    }
}
