import FileList
import Foundation

enum ExternalSelectionPathMatcher {
    static func standardizedPath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    static func matchingItem(in items: [FileItem], selectionPath: String) -> FileItem? {
        let standardized = standardizedPath(selectionPath)
        return items.first { $0.id == standardized || $0.id == selectionPath }
    }
}
