import Foundation

public enum DirectoryListingFSEventsPolicy {
    /// 事件是否影响当前目录的直接子项列表（不含子目录内部变化）。
    public static func listingAffectedByEvents(
        eventPaths: [String],
        directoryPath: String
    ) -> Bool {
        guard !eventPaths.isEmpty, !directoryPath.isEmpty else { return false }
        let directory = DirectoryListingPathNormalization.canonicalPath(directoryPath)
        for eventPath in eventPaths {
            let normalizedEvent = DirectoryListingPathNormalization.canonicalPath(eventPath)
            if normalizedEvent == directory { return true }
            let parent = DirectoryListingPathNormalization.canonicalPath(
                (eventPath as NSString).deletingLastPathComponent
            )
            if parent == directory { return true }
        }
        return false
    }
}
