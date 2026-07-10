import Foundation

/// 按优先级 BFS 调度目录 listing 加载。
@MainActor
final class PanoramaTreeBootstrapper {
    enum Priority: Int, Sendable {
        case low = 0
        case high = 1
        case visible = 2

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private struct Entry: Comparable {
        let path: String
        let depth: Int
        let priority: Priority

        static func < (lhs: Entry, rhs: Entry) -> Bool {
            if lhs.priority.rawValue != rhs.priority.rawValue {
                return lhs.priority.rawValue < rhs.priority.rawValue
            }
            if lhs.depth != rhs.depth {
                return lhs.depth < rhs.depth
            }
            return lhs.path < rhs.path
        }
    }

    private var pending: [Entry] = []
    private var pendingPaths: Set<String> = []
    private var sessionGeneration: UInt = 0

    func reset(sessionGeneration: UInt) {
        self.sessionGeneration = sessionGeneration
        pending.removeAll(keepingCapacity: true)
        pendingPaths.removeAll(keepingCapacity: true)
    }

    func schedule(
        sessionGeneration: UInt,
        dataSource: PanoramaTreeDataSource,
        collapseState: PanoramaTreeCollapseState,
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String> = []
    ) {
        self.sessionGeneration = sessionGeneration
        pending.removeAll(keepingCapacity: true)
        pendingPaths.removeAll(keepingCapacity: true)

        seedExpandedDirectories(
            dataSource: dataSource,
            collapseState: collapseState,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )

        processBatch(
            dataSource: dataSource,
            sessionGeneration: sessionGeneration
        )
    }

    func listingDidUpdate(
        path: String,
        dataSource: PanoramaTreeDataSource,
        collapseState: PanoramaTreeCollapseState,
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String> = []
    ) {
        enqueueChildren(
            of: path,
            parentAncestorDirectoryIDs: ancestorDirectoryIDs(for: path, dataSource: dataSource),
            dataSource: dataSource,
            collapseState: collapseState,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )

        processBatch(
            dataSource: dataSource,
            sessionGeneration: sessionGeneration
        )
    }

    func boostVisiblePaths(
        dataSource: PanoramaTreeDataSource,
        collapseState: PanoramaTreeCollapseState,
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String> = []
    ) {
        reprioritizeVisibleEntries(
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )

        seedExpandedDirectories(
            dataSource: dataSource,
            collapseState: collapseState,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )

        processBatch(
            dataSource: dataSource,
            sessionGeneration: sessionGeneration
        )
    }

    // MARK: - Queue

    private func seedExpandedDirectories(
        dataSource: PanoramaTreeDataSource,
        collapseState: PanoramaTreeCollapseState,
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String>
    ) {
        guard case let .loaded(rootItems) = dataSource.rootListing else { return }

        for item in rootItems where item.isDirectory {
            guard collapseState.isExpanded(item.id) else { continue }

            visitDirectory(
                path: item.id,
                depth: nodeDepth(for: item.id, dataSource: dataSource),
                ancestorDirectoryIDs: [],
                dataSource: dataSource,
                collapseState: collapseState,
                depthPolicy: depthPolicy,
                visibleDirectoryPaths: visibleDirectoryPaths,
                prefetchDirectoryPaths: prefetchDirectoryPaths
            )
        }
    }

    private func visitDirectory(
        path: String,
        depth: Int,
        ancestorDirectoryIDs: [String],
        dataSource: PanoramaTreeDataSource,
        collapseState: PanoramaTreeCollapseState,
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String>
    ) {
        guard collapseState.isSubtreeVisible(for: path, ancestorIDs: ancestorDirectoryIDs) else {
            return
        }

        maybeEnqueue(
            path: path,
            depth: depth,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths,
            listing: dataSource.listing(for: path)
        )

        guard case let .loaded(items) = dataSource.listing(for: path) else { return }

        let ancestors = ancestorDirectoryIDs + [path]
        for item in items where item.isDirectory {
            guard collapseState.isExpanded(item.id) else { continue }
            visitDirectory(
                path: item.id,
                depth: depth + 1,
                ancestorDirectoryIDs: ancestors,
                dataSource: dataSource,
                collapseState: collapseState,
                depthPolicy: depthPolicy,
                visibleDirectoryPaths: visibleDirectoryPaths,
                prefetchDirectoryPaths: prefetchDirectoryPaths
            )
        }
    }

    private func enqueueChildren(
        of path: String,
        parentAncestorDirectoryIDs: [String],
        dataSource: PanoramaTreeDataSource,
        collapseState: PanoramaTreeCollapseState,
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String>
    ) {
        guard case let .loaded(items) = dataSource.listing(for: path) else { return }

        let depth = nodeDepth(for: path, dataSource: dataSource)
        let ancestors = parentAncestorDirectoryIDs + [path]
        for item in items where item.isDirectory {
            guard collapseState.isExpanded(item.id) else { continue }
            visitDirectory(
                path: item.id,
                depth: depth + 1,
                ancestorDirectoryIDs: ancestors,
                dataSource: dataSource,
                collapseState: collapseState,
                depthPolicy: depthPolicy,
                visibleDirectoryPaths: visibleDirectoryPaths,
                prefetchDirectoryPaths: prefetchDirectoryPaths
            )
        }
    }

    private func maybeEnqueue(
        path: String,
        depth: Int,
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String>,
        listing: PanoramaListingState
    ) {
        switch listing {
        case .loaded, .loading:
            return
        case .unloaded, .failed:
            break
        }

        let priority = priority(
            for: path,
            depth: depth,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )
        enqueue(path: path, depth: depth, priority: priority)
    }

    private func enqueue(path: String, depth: Int, priority: Priority) {
        guard !pendingPaths.contains(path) else {
            reprioritizeExistingEntry(path: path, priority: priority)
            return
        }

        pending.append(Entry(path: path, depth: depth, priority: priority))
        pendingPaths.insert(path)
    }

    private func reprioritizeExistingEntry(path: String, priority: Priority) {
        guard let index = pending.firstIndex(where: { $0.path == path }) else { return }
        let existing = pending[index]
        pending[index] = Entry(
            path: existing.path,
            depth: existing.depth,
            priority: Priority(rawValue: max(existing.priority.rawValue, priority.rawValue)) ?? priority
        )
    }

    private func reprioritizeVisibleEntries(
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String>
    ) {
        for index in pending.indices {
            let entry = pending[index]
            let boostedPriority = priority(
                for: entry.path,
                depth: entry.depth,
                depthPolicy: depthPolicy,
                visibleDirectoryPaths: visibleDirectoryPaths,
                prefetchDirectoryPaths: prefetchDirectoryPaths
            )
            pending[index] = Entry(
                path: entry.path,
                depth: entry.depth,
                priority: Priority(rawValue: max(entry.priority.rawValue, boostedPriority.rawValue)) ?? boostedPriority
            )
        }
    }

    private func processBatch(
        dataSource: PanoramaTreeDataSource,
        sessionGeneration: UInt
    ) {
        guard sessionGeneration == self.sessionGeneration else { return }
        guard dataSource.generation == sessionGeneration else { return }

        pending.sort(by: >)

        var started = 0
        while started < PanoramaMetrics.bootstrapBatchSize, !pending.isEmpty {
            let entry = pending.removeFirst()
            pendingPaths.remove(entry.path)

            switch dataSource.listing(for: entry.path) {
            case .loaded, .loading:
                continue
            case .unloaded, .failed:
                dataSource.loadListing(for: entry.path)
                started += 1
            }
        }
    }

    private func priority(
        for path: String,
        depth: Int,
        depthPolicy: PanoramaExpandDepthPolicy,
        visibleDirectoryPaths: Set<String>,
        prefetchDirectoryPaths: Set<String>
    ) -> Priority {
        if visibleDirectoryPaths.contains(path) {
            return .visible
        }
        if prefetchDirectoryPaths.contains(path) {
            return .high
        }
        if let maxDepth = depthPolicy.bootstrapPriorityMaxDepth {
            return depth <= maxDepth ? .high : .low
        }
        return .high
    }

    private func nodeDepth(for path: String, dataSource: PanoramaTreeDataSource) -> Int {
        dataSource.node(for: path)?.depth ?? 0
    }

    private func ancestorDirectoryIDs(for path: String, dataSource: PanoramaTreeDataSource) -> [String] {
        guard path != dataSource.rootDirectoryPath else { return [] }

        var ancestors: [String] = []
        var currentURL = URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL
        let rootPath = URL(fileURLWithPath: dataSource.rootDirectoryPath).standardizedFileURL.path

        while currentURL.path != rootPath {
            ancestors.insert(currentURL.path, at: 0)
            let parentURL = currentURL.deletingLastPathComponent().standardizedFileURL
            if parentURL.path == currentURL.path {
                break
            }
            currentURL = parentURL
        }

        return ancestors
    }
}

#if DEBUG
extension PanoramaTreeBootstrapper {
    var pendingEntriesForTesting: [(path: String, priority: Priority)] {
        pending.sorted(by: >).map { ($0.path, $0.priority) }
    }
}
#endif
