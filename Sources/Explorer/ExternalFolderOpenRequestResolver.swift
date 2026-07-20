import Foundation

enum ExternalFolderOpenRequestResolver {
    struct ResolvedRequest: Equatable {
        let directoryPath: String
        let selectionPath: String?
    }

    static func resolve(from urls: [URL]) -> ResolvedRequest? {
        for url in urls {
            if let resolved = resolveSingle(url) {
                return resolved
            }
        }
        return nil
    }

    /// 路径栏文本：废纸篓别名、引号、`file://`、`~` 展开后按目录/文件解析。
    /// 文件路径 → 父目录 + 待选中项；目录路径 → 仅目录。
    static func resolve(fromPathText text: String) -> ResolvedRequest? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if TrashLoader.isTrashInput(trimmed) {
            return ResolvedRequest(directoryPath: TrashLoader.userTrashPath, selectionPath: nil)
        }

        let cleaned = stripWrappingQuotes(trimmed)
        if cleaned.lowercased().hasPrefix("file:"), let url = URL(string: cleaned) {
            return resolveSingle(url)
        }

        let expanded = (cleaned as NSString).expandingTildeInPath
        return resolveSingle(URL(fileURLWithPath: expanded))
    }

    private static func stripWrappingQuotes(_ text: String) -> String {
        guard text.count >= 2 else { return text }
        if (text.hasPrefix("\"") && text.hasSuffix("\""))
            || (text.hasPrefix("'") && text.hasSuffix("'")) {
            return String(text.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func resolveSingle(_ url: URL) -> ResolvedRequest? {
        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory)

        if exists {
            if isDirectory.boolValue {
                return ResolvedRequest(directoryPath: standardized.path, selectionPath: nil)
            }
            let parentDirectory = standardized.deletingLastPathComponent()
            guard parentDirectory.path != standardized.path else { return nil }
            return ResolvedRequest(
                directoryPath: parentDirectory.path,
                selectionPath: standardized.path
            )
        }

        // 第三方「在访达中显示」可能传入当前进程无法 stat 的路径（如其他 App 容器目录），
        // 仍按路径结构打开父目录并尝试选中，避免完全无响应。
        if standardized.hasDirectoryPath {
            return ResolvedRequest(directoryPath: standardized.path, selectionPath: nil)
        }
        let parentDirectory = standardized.deletingLastPathComponent()
        guard parentDirectory.path != standardized.path else { return nil }
        return ResolvedRequest(
            directoryPath: parentDirectory.path,
            selectionPath: standardized.path
        )
    }
}
