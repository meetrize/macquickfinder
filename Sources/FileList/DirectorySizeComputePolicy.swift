import Foundation

public enum DirectorySizeComputeResult: Sendable, Equatable {
    case complete(Int64)
    case lowerBound(Int64)
}

public enum DirectorySizeComputePolicy {
    public static let maxEnumeratedFiles = 100_000
    public static let maxComputeDuration: Duration = .seconds(60)
    
    public static func shouldStopEnumerating(
        fileCount: Int,
        startedAt: ContinuousClock.Instant,
        now: ContinuousClock.Instant
    ) -> Bool {
        fileCount >= maxEnumeratedFiles || now >= startedAt + maxComputeDuration
    }
    
    public static func foldersAffectedByEvents(
        eventPaths: [String],
        listedFolderPaths: Set<String>
    ) -> [String] {
        guard !eventPaths.isEmpty, !listedFolderPaths.isEmpty else { return [] }
        var affected = Set<String>()
        for eventPath in eventPaths {
            for folderPath in listedFolderPaths {
                if eventPath == folderPath || eventPath.hasPrefix(folderPath + "/") {
                    affected.insert(folderPath)
                }
            }
        }
        return affected.sorted()
    }
}
