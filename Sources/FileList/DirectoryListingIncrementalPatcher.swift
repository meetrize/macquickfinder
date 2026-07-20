import Foundation

/// 根据 FSEvents 推导目录直接子项的增量增删（无法安全增量时要求全量 reload）。
public enum DirectoryListingIncrementalPatcher {
    public struct Patch: Sendable, Equatable {
        public var addedPaths: [String]
        public var removedPaths: [String]

        public var isEmpty: Bool {
            addedPaths.isEmpty && removedPaths.isEmpty
        }
    }

    public enum Result: Sendable, Equatable {
        case noListingChange
        case patch(Patch)
        case requiresFullReload
    }

    public static let maxIncrementalEventCount = 24

    public static func evaluate(
        events: [DirectoryFSEvent],
        directoryPath: String
    ) -> Result {
        guard !events.isEmpty, !directoryPath.isEmpty else { return .noListingChange }
        guard events.count <= maxIncrementalEventCount else { return .requiresFullReload }

        let directory = DirectoryListingPathNormalization.canonicalPath(directoryPath)
        var added: [String] = []
        var removed: [String] = []
        var requiresReload = false

        for event in events {
            let normalizedEvent = DirectoryListingPathNormalization.canonicalPath(event.path)
            if normalizedEvent == directory {
                requiresReload = true
                continue
            }

            let parent = DirectoryListingPathNormalization.canonicalPath(
                (event.path as NSString).deletingLastPathComponent
            )
            guard parent == directory else { continue }

            if event.isRenamed {
                requiresReload = true
                continue
            }

            if event.isCreated {
                added.append(normalizedEvent)
            }
            if event.isRemoved {
                removed.append(normalizedEvent)
            }
        }

        if requiresReload {
            return .requiresFullReload
        }

        let addedSet = Set(added)
        let removedSet = Set(removed)
        if !addedSet.isDisjoint(with: removedSet) {
            return .requiresFullReload
        }

        let patch = Patch(
            addedPaths: addedSet.sorted(),
            removedPaths: removedSet.sorted()
        )
        if patch.isEmpty {
            return .noListingChange
        }
        return .patch(patch)
    }
}
