import Foundation

enum SnippetExpansionError: LocalizedError, Equatable {
    case requiresSingleSelection
    case requiresSelection
    case requiresFileSelection
    case requiresFilesInSelection
    case noFilesInSelection

    var errorDescription: String? {
        switch self {
        case .requiresSingleSelection: return "需要恰好选中一项"
        case .requiresSelection: return "需要至少选中一项"
        case .requiresFileSelection: return "需要选中一个文件（非目录）"
        case .requiresFilesInSelection: return "需要选中至少一个文件"
        case .noFilesInSelection: return "选中项中没有文件"
        }
    }
}

enum SnippetExpander {
    static func expand(
        _ template: String,
        context: SnippetExecutionContext,
        scriptType: SnippetScriptType = .shell
    ) throws -> String {
        let files = context.selectedItems.filter { !$0.isParentDirectoryEntry && !$0.isDirectory }
        let allSelected = context.selectedItems.filter { !$0.isParentDirectoryEntry }
        
        func pathForScript(_ path: String) -> String {
            let standardized = standardize(path)
            if scriptType == .shell {
                return shellQuote(standardized)
            }
            return standardized
        }

        var result = template
        let replacements: [(String, () throws -> String)] = [
            ("%p", {
                guard allSelected.count == 1, let item = allSelected.first else {
                    throw SnippetExpansionError.requiresSingleSelection
                }
                return pathForScript(item.url.path)
            }),
            ("%d", { standardize(context.cwd) }),
            ("%P", {
                guard !allSelected.isEmpty else { throw SnippetExpansionError.requiresSelection }
                return allSelected.map { pathForScript($0.url.path) }.joined(separator: " ")
            }),
            ("%f", {
                guard allSelected.count == 1, let item = allSelected.first, !item.isDirectory else {
                    throw SnippetExpansionError.requiresFileSelection
                }
                return pathForScript(item.url.path)
            }),
            ("%F", {
                guard !files.isEmpty else { throw SnippetExpansionError.noFilesInSelection }
                return files.map { pathForScript($0.url.path) }.joined(separator: " ")
            }),
            ("%n", {
                guard allSelected.count == 1, let item = allSelected.first else {
                    throw SnippetExpansionError.requiresSingleSelection
                }
                return item.name
            }),
            ("%b", {
                guard allSelected.count == 1, let item = allSelected.first else {
                    throw SnippetExpansionError.requiresSingleSelection
                }
                return (item.name as NSString).deletingPathExtension
            }),
            ("%e", {
                guard allSelected.count == 1, let item = allSelected.first else {
                    throw SnippetExpansionError.requiresSingleSelection
                }
                return item.url.pathExtension.lowercased()
            }),
            ("%N", { String(allSelected.count) }),
            ("%q", {
                guard allSelected.count == 1, let item = allSelected.first else {
                    throw SnippetExpansionError.requiresSingleSelection
                }
                return shellQuote(standardize(item.url.path))
            }),
            ("%Q", {
                guard !allSelected.isEmpty else { throw SnippetExpansionError.requiresSelection }
                return allSelected.map { shellQuote(standardize($0.url.path)) }.joined(separator: " ")
            }),
            ("%h", { standardize(FileManager.default.homeDirectoryForCurrentUser.path) }),
            ("%u", { NSUserName() }),
            ("%w", {
                let name = URL(fileURLWithPath: context.cwd).lastPathComponent
                return name.isEmpty ? context.cwd : name
            }),
            ("%date", {
                ISO8601DateFormatter().string(from: Date())
            }),
            ("%uuid", { UUID().uuidString }),
        ]

        for (placeholder, value) in replacements {
            while result.contains(placeholder) {
                let expanded = try value()
                if let range = result.range(of: placeholder) {
                    result.replaceSubrange(range, with: expanded)
                }
            }
        }
        return result
    }

    static func standardize(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    static func shellQuote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
