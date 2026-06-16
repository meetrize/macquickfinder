import Foundation

public enum DirectoryListingFSEventsPolicy {
    /// 事件是否影响当前目录的直接子项列表（不含子目录内部变化）。
    public static func listingAffectedByEvents(
        eventPaths: [String],
        directoryPath: String
    ) -> Bool {
        guard !eventPaths.isEmpty, !directoryPath.isEmpty else { return false }
        let directory = normalizedPath(directoryPath)
        for eventPath in eventPaths {
            let normalizedEvent = normalizedPath(eventPath)
            if normalizedEvent == directory { return true }
            let parent = normalizedPath((eventPath as NSString).deletingLastPathComponent)
            if parent == directory { return true }
        }
        return false
    }
    
    private static func normalizedPath(_ path: String) -> String {
        var result = path
        while result.count > 1, result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}
