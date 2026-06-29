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
