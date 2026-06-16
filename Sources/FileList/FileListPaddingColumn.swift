import AppKit
import Foundation

/// Date Modified 之后的透明留白列（不参与排序/持久化/表头菜单）。
enum FileListPaddingColumn {
    static let identifier = "__file_list_padding__"
    
    static func isPadding(_ column: NSTableColumn) -> Bool {
        column.identifier.rawValue == identifier
    }
    
    static func column(in tableView: NSTableView) -> NSTableColumn? {
        tableView.tableColumns.first(where: isPadding)
    }
    
    static func makeColumn() -> NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = ""
        column.minWidth = 0
        column.maxWidth = CGFloat.greatestFiniteMagnitude
        column.resizingMask = []
        column.headerCell.title = ""
        if #available(macOS 12.0, *) {
            column.isHidden = false
        }
        return column
    }
}
