import Foundation

enum SnippetExpansionError: LocalizedError, Equatable {
    case requiresSingleSelection
    case requiresSelection
    case requiresFileSelection
    case requiresFilesInSelection
    case noFilesInSelection

    var errorDescription: String? {
        switch self {
        case .requiresSingleSelection: return L10n.Error.SnippetExpansion.singleSelection
        case .requiresSelection: return L10n.Error.SnippetExpansion.requiresSelection
        case .requiresFileSelection: return L10n.Error.SnippetExpansion.fileSelection
        case .requiresFilesInSelection: return L10n.Error.SnippetExpansion.filesInSelection
        case .noFilesInSelection: return L10n.Error.SnippetExpansion.noFiles
        }
    }
}

enum SnippetExpander {
    /// 哨兵前缀，避免与用户输入 / 上下文路径碰撞。
    private static let askSentinelPrefix = "\u{FFF0}MEOFIND_ASK_"
    private static let askSentinelSuffix = "\u{FFF1}"

    static func expand(
        _ template: String,
        context: SnippetExecutionContext,
        scriptType: SnippetScriptType = .shell,
        askValues: [String: String] = [:]
    ) throws -> String {
        let askMatches = try SnippetAskParser.matches(in: template)
        var working = template
        var sentinelToValue: [String: String] = [:]

        // 从后往前替换，保持 Range 有效；用户值稍后回填，避免二次展开 `%p`。
        for (index, match) in askMatches.enumerated().reversed() {
            let raw = askValues[match.parameter.key] ?? ""
            let prepared = prepareAskValue(raw, scriptType: scriptType)
            let sentinel = "\(askSentinelPrefix)\(index)\(askSentinelSuffix)"
            sentinelToValue[sentinel] = prepared
            working.replaceSubrange(match.range, with: sentinel)
        }

        working = try expandContextVariables(working, context: context, scriptType: scriptType)

        for (sentinel, value) in sentinelToValue {
            working = working.replacingOccurrences(of: sentinel, with: value)
        }
        return working
    }

    private static func prepareAskValue(_ value: String, scriptType: SnippetScriptType) -> String {
        if scriptType == .shell {
            return ShellQuoting.singleQuote(value)
        }
        return value
    }

    private static func expandContextVariables(
        _ template: String,
        context: SnippetExecutionContext,
        scriptType: SnippetScriptType
    ) throws -> String {
        let files = context.selectedItems.filter { !$0.isParentDirectoryEntry && !$0.isDirectory }
        let allSelected = context.selectedItems.filter { !$0.isParentDirectoryEntry }

        func pathForScript(_ path: String) -> String {
            let standardized = standardize(path)
            if scriptType == .shell {
                return ShellQuoting.singleQuote(standardized)
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
                return ShellQuoting.singleQuote(standardize(item.url.path))
            }),
            ("%Q", {
                guard !allSelected.isEmpty else { throw SnippetExpansionError.requiresSelection }
                return allSelected.map { ShellQuoting.singleQuote(standardize($0.url.path)) }.joined(separator: " ")
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

        // 长 token 优先，避免短前缀误伤（如将来 `%ask` 残留）。
        let ordered = replacements.sorted { $0.0.count > $1.0.count }
        for (placeholder, value) in ordered {
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
}
