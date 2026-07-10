import FileList
import Foundation

/// 子目录全景的树形 listing 缓存与异步加载。
@MainActor
final class PanoramaTreeDataSource {
    private(set) var rootDirectoryPath: String = ""
    private(set) var rootListing: PanoramaListingState = .unloaded
    private(set) var generation: UInt = 0

    private var nodesByPath: [String: PanoramaDirectoryNode] = [:]
    private var listingGenerationByPath: [String: UInt] = [:]
    private var loadedAccessOrder: [String] = []

    var showHiddenFiles: Bool = false
    var sort: FileListSortState = .default
    var onListingDidUpdate: ((String) -> Void)?

    private let maxCachedDirectoryListings: Int

    init(maxCachedDirectoryListings: Int = PanoramaMetrics.maxCachedDirectoryListings) {
        self.maxCachedDirectoryListings = max(1, maxCachedDirectoryListings)
    }

    var allNodes: [PanoramaDirectoryNode] {
        Array(nodesByPath.values)
    }

    func node(for path: String) -> PanoramaDirectoryNode? {
        nodesByPath[path]
    }

    func listing(for path: String) -> PanoramaListingState {
        if path == rootDirectoryPath {
            return rootListing
        }
        return nodesByPath[path]?.listing ?? .unloaded
    }

    func loadedItems(for path: String) -> [FileItem]? {
        listing(for: path).loadedItems
    }

    // MARK: - Root lifecycle

    func reset(rootPath: String, rootItems: [FileItem]) {
        generation &+= 1
        nodesByPath.removeAll(keepingCapacity: true)
        listingGenerationByPath.removeAll(keepingCapacity: true)
        loadedAccessOrder.removeAll(keepingCapacity: true)
        rootDirectoryPath = rootPath
        applyRootItems(rootItems)
    }

    func applyRootItems(_ items: [FileItem]) {
        guard !rootDirectoryPath.isEmpty else { return }

        let sorted = sortedItems(items)
        rootListing = .loaded(sorted)
        noteLoaded(path: rootDirectoryPath)
        registerDirectoryNodes(from: sorted, parentDepth: -1)
    }

    func evictLoadedListings(except retainedPaths: Set<String>) {
        let victims = loadedAccessOrder.filter { path in
            path != rootDirectoryPath && !retainedPaths.contains(path)
        }
        for path in victims {
            evictListing(for: path)
        }
    }

    // MARK: - Listing load / evict

    func loadListing(for path: String) {
        guard !rootDirectoryPath.isEmpty else { return }

        if path == rootDirectoryPath {
            if case .loaded = rootListing {
                noteLoaded(path: path)
            }
            return
        }

        guard var node = nodesByPath[path], node.item.isDirectory else { return }
        if case .loading = node.listing { return }

        let loadGeneration = nextListingGeneration(for: path)
        let sessionGeneration = generation
        let parentDepth = node.depth
        node.listing = .loading
        nodesByPath[path] = node

        let shouldShowHiddenFiles = showHiddenFiles
        let listingOptions = DirectoryListingOptions.forPath(path)
        let rootCanonical = canonicalPath(rootDirectoryPath)

        Task.detached(priority: .userInitiated) {
            do {
                let canonicalPath = Self.canonicalPath(path)
                if canonicalPath == rootCanonical {
                    throw PanoramaTreeDataSourceError.symlinkLoop
                }

                let loaded = try DirectoryListingLoader.loadFileItems(
                    at: path,
                    showHiddenFiles: shouldShowHiddenFiles,
                    options: listingOptions
                )

                await MainActor.run {
                    self.finishLoadListing(
                        path: path,
                        sessionGeneration: sessionGeneration,
                        loadGeneration: loadGeneration,
                        parentDepth: parentDepth,
                        result: .success(loaded)
                    )
                }
            } catch {
                await MainActor.run {
                    self.finishLoadListing(
                        path: path,
                        sessionGeneration: sessionGeneration,
                        loadGeneration: loadGeneration,
                        parentDepth: parentDepth,
                        result: .failure(error)
                    )
                }
            }
        }
    }

    func evictListing(for path: String) {
        guard path != rootDirectoryPath else { return }

        if var node = nodesByPath[path] {
            node.listing = .unloaded
            nodesByPath[path] = node
        }

        removeDescendantNodes(under: path)
        loadedAccessOrder.removeAll { $0 == path }
    }

    // MARK: - Private

    private enum PanoramaTreeDataSourceError: Error {
        case symlinkLoop
    }

    private func finishLoadListing(
        path: String,
        sessionGeneration: UInt,
        loadGeneration: UInt,
        parentDepth: Int,
        result: Result<[FileItem], Error>
    ) {
        guard sessionGeneration == generation,
              loadGeneration == listingGenerationByPath[path]
        else { return }

        guard var node = nodesByPath[path] else { return }

        switch result {
        case let .success(items):
            let sorted = sortedItems(items)
            node.listing = .loaded(sorted)
            nodesByPath[path] = node
            registerDirectoryNodes(from: sorted, parentDepth: parentDepth)
            noteLoaded(path: path)
            onListingDidUpdate?(path)
        case let .failure(error):
            node.listing = .failed(listingErrorMessage(for: error))
            nodesByPath[path] = node
            onListingDidUpdate?(path)
        }
    }

    private func registerDirectoryNodes(from items: [FileItem], parentDepth: Int) {
        let childDepth = parentDepth + 1
        for item in items where item.isDirectory {
            if var existing = nodesByPath[item.id] {
                existing.childCountHint = nil
                nodesByPath[item.id] = existing
            } else {
                nodesByPath[item.id] = PanoramaDirectoryNode(
                    item: item,
                    depth: childDepth
                )
            }
        }
    }

    private func sortedItems(_ items: [FileItem]) -> [FileItem] {
        guard !items.isEmpty else { return [] }

        let rows = items.map { FileListRow(item: $0) }
        let sortedRows = FileListSortEngine.sorted(rows, by: sort)
        let order = sortedRows.map(\.id)
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return order.compactMap { byID[$0] }
    }

    private func nextListingGeneration(for path: String) -> UInt {
        let next = (listingGenerationByPath[path] ?? 0) + 1
        listingGenerationByPath[path] = next
        return next
    }

    private func noteLoaded(path: String) {
        loadedAccessOrder.removeAll { $0 == path }
        loadedAccessOrder.append(path)
        enforceLRUCap()
    }

    private func enforceLRUCap() {
        while loadedListingCount() > maxCachedDirectoryListings {
            guard let victim = loadedAccessOrder.first(where: { $0 != rootDirectoryPath }) else {
                break
            }
            evictListing(for: victim)
        }
    }

    private func loadedListingCount() -> Int {
        var count = rootListing.isLoaded ? 1 : 0
        for node in nodesByPath.values where node.listing.isLoaded {
            count += 1
        }
        return count
    }

    private func removeDescendantNodes(under path: String) {
        let prefix = path.hasSuffix("/") ? path : path + "/"
        for key in nodesByPath.keys where key.hasPrefix(prefix) {
            nodesByPath.removeValue(forKey: key)
            listingGenerationByPath.removeValue(forKey: key)
            loadedAccessOrder.removeAll { $0 == key }
        }
    }

    private func listingErrorMessage(for error: Error) -> String {
        if error is PanoramaTreeDataSourceError {
            return L10n.Error.symlinkLoop
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
            return L10n.Error.noPermission
        }
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
            return L10n.Error.directoryNotFound
        }
        return nsError.localizedDescription
    }

    private func canonicalPath(_ path: String) -> String {
        Self.canonicalPath(path)
    }

    nonisolated private static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }
}

#if DEBUG
extension PanoramaTreeDataSource {
    var loadedPathsForTesting: [String] {
        loadedAccessOrder
    }

    var nodeCountForTesting: Int {
        nodesByPath.count
    }
}
#endif
