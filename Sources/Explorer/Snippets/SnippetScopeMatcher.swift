import Foundation

enum SnippetScopeMatcher {
    static func isVisible(_ snippet: Snippet, context: SnippetVisibilityContext) -> Bool {
        isVisible(scope: snippet.scope, context: context)
    }

    static func isVisible(scope: SnippetScope, context: SnippetVisibilityContext) -> Bool {
        let sel = context.selectedItems.filter { !$0.isParentDirectoryEntry }
        switch scope {
        case .anytime:
            return true
        case .global:
            return !sel.isEmpty
        case .filesOnly:
            return !sel.isEmpty && sel.allSatisfy { !$0.isDirectory }
        case .directoriesOnly:
            return !sel.isEmpty && sel.allSatisfy(\.isDirectory)
        case .singleSelection:
            return sel.count == 1
        case .fileExtensions(let exts):
            let set = Set(exts.map { $0.lowercased() })
            return sel.contains { item in
                !item.isDirectory && set.contains(item.url.pathExtension.lowercased())
            }
        case .specificFiles(let paths):
            let set = Set(paths.map { ($0 as NSString).standardizingPath })
            return sel.contains { set.contains(($0.url.path as NSString).standardizingPath) }
        }
    }
}
