import AppKit
import Foundation

/// 从剪贴板解析可导航的本地路径（供路径栏面包屑右键等使用）。
enum ClipboardPathResolver {
    /// 剪贴板含可打开路径时返回解析结果；目录须存在。
    static func resolve(
        pasteboard: NSPasteboard = .general
    ) -> ExternalFolderOpenRequestResolver.ResolvedRequest? {
        if let fromURLs = resolveFileURLs(from: pasteboard) {
            return validated(fromURLs)
        }
        guard let raw = pasteboard.string(forType: .string) else { return nil }
        let firstLine = String(raw.prefix(while: { !$0.isNewline }))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstLine.isEmpty, looksLikePath(firstLine) else { return nil }
        guard let resolved = ExternalFolderOpenRequestResolver.resolve(fromPathText: firstLine) else {
            return nil
        }
        return validated(resolved)
    }

    static func hasResolvablePath(pasteboard: NSPasteboard = .general) -> Bool {
        resolve(pasteboard: pasteboard) != nil
    }

    private static func resolveFileURLs(
        from pasteboard: NSPasteboard
    ) -> ExternalFolderOpenRequestResolver.ResolvedRequest? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty else {
            return nil
        }
        return ExternalFolderOpenRequestResolver.resolve(from: urls)
    }

    /// 避免普通句子被当成相对路径；仅接受绝对/`~`/`file:` 形态。
    static func looksLikePath(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let unquoted: String
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")),
           trimmed.count >= 2 {
            unquoted = String(trimmed.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            unquoted = trimmed
        }
        if unquoted.hasPrefix("/") || unquoted.hasPrefix("~") { return true }
        if unquoted.lowercased().hasPrefix("file:") { return true }
        return false
    }

    private static func validated(
        _ resolved: ExternalFolderOpenRequestResolver.ResolvedRequest
    ) -> ExternalFolderOpenRequestResolver.ResolvedRequest? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: resolved.directoryPath,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            return nil
        }
        // 外部解析器对「不存在的文件路径」仍会给出父目录；面包屑菜单要求目标真实存在。
        if let selectionPath = resolved.selectionPath {
            guard FileManager.default.fileExists(atPath: selectionPath) else {
                return nil
            }
        }
        return resolved
    }
}
