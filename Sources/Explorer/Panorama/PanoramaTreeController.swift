import Combine
import FileList
import Foundation

/// 子目录全景：listing 缓存、收起状态、展示构建与渐进加载编排。
@MainActor
final class PanoramaTreeController: ObservableObject {
    @Published private(set) var displayRoot = PanoramaDisplayRoot(rootDirectoryPath: "", blocks: [])

    let dataSource = PanoramaTreeDataSource()
    let thumbnailScheduler = PanoramaThumbnailScheduler()
    let cellTracker = PanoramaVisibleCellTracker()
    private(set) var collapseState = PanoramaTreeCollapseState()

    private let bootstrapper = PanoramaTreeBootstrapper()
    private var depthPolicy: PanoramaExpandDepthPolicy = .automatic
    private var visibleDirectoryPaths: Set<String> = []
    private var prefetchDirectoryPaths: Set<String> = []
    private var visibilityWorkItem: DispatchWorkItem?
    private var memoryPressureObserver: NSObjectProtocol?
    private var thumbnailCatalog = PanoramaThumbnailCatalogBuilder.Catalog(
        orderedRowIDs: [],
        rowsByID: [:],
        directoryIDByRowID: [:]
    )
    private var thumbnailCellSize: CGFloat = FileListThumbnailMetrics.defaultCellSize
    private var thumbnailScreenScale: CGFloat = 2
    private var preferWorkspaceIconsInThumbnail = false

    init() {
        dataSource.onListingDidUpdate = { [weak self] path in
            self?.handleListingDidUpdate(path: path)
        }

        cellTracker.onVisibilityChanged = { [weak self] snapshot in
            self?.applyCellVisibility(snapshot)
        }

        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: .meoFindMemoryPressure,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.respondToMemoryPressure()
            }
        }
    }

    deinit {
        if let memoryPressureObserver {
            NotificationCenter.default.removeObserver(memoryPressureObserver)
        }
    }

    // MARK: - Lifecycle

    func reset(
        rootPath: String,
        rootItems: [FileItem],
        showHiddenFiles: Bool,
        sort: FileListSortState,
        depthPolicy: PanoramaExpandDepthPolicy = .automatic
    ) {
        visibilityWorkItem?.cancel()
        self.depthPolicy = depthPolicy
        visibleDirectoryPaths = [rootPath]
        prefetchDirectoryPaths = []
        collapseState.clear()

        dataSource.showHiddenFiles = showHiddenFiles
        dataSource.sort = sort
        dataSource.reset(rootPath: rootPath, rootItems: rootItems)

        bootstrapper.reset(sessionGeneration: dataSource.generation)
        rebuildDisplay()
        scheduleBootstrap()
    }

    func applyRootItems(_ items: [FileItem]) {
        dataSource.applyRootItems(items)
        rebuildDisplay()
        scheduleBootstrap()
    }

    func shutdown() {
        visibilityWorkItem?.cancel()
        cellTracker.reset()
        thumbnailScheduler.shutdown()
        bootstrapper.reset(sessionGeneration: dataSource.generation &+ 1)
        dataSource.evictLoadedListings(except: [dataSource.rootDirectoryPath])
        rebuildDisplay()
    }

    func respondToMemoryPressure() {
        let retained = visibleDirectoryPaths.union(prefetchDirectoryPaths)
            .union([dataSource.rootDirectoryPath])
        dataSource.evictLoadedListings(except: retained)
        thumbnailScheduler.respondToMemoryPressure()
        rebuildDisplay()
        scheduleBootstrap()
    }

    func configureThumbnailLoading(
        cellSize: CGFloat,
        screenScale: CGFloat,
        preferWorkspaceIcons: Bool
    ) {
        thumbnailCellSize = FileListThumbnailMetrics.steppedCellSize(from: cellSize)
        thumbnailScreenScale = screenScale
        preferWorkspaceIconsInThumbnail = preferWorkspaceIcons
        updateThumbnailScheduler(visibleRowIDs: cellTracker.snapshot.visibleRowIDs)
    }

    func submitCellVisibility(
        cellReports: [PanoramaCellVisibility],
        viewport: CGRect
    ) {
        cellTracker.submit(cellReports: cellReports, viewport: viewport)
    }

    // MARK: - Collapse

    func isExpanded(_ directoryID: String) -> Bool {
        collapseState.isExpanded(directoryID)
    }

    func toggleCollapse(_ directoryID: String) {
        if collapseState.isExpanded(directoryID) {
            collapseState.collapse(directoryID)
        } else {
            collapseState.expand(directoryID)
        }
        rebuildDisplay()
        scheduleBootstrap()
    }

    func expandAll() {
        collapseState.expandAll()
        rebuildDisplay()
        scheduleBootstrap()
    }

    func collapseAll() {
        let directoryIDs = dataSource.allNodes.map(\.path)
        collapseState.collapseAll(directoryIDs: directoryIDs)
        rebuildDisplay()
        scheduleBootstrap()
    }

    // MARK: - Visibility

    func onVisibleDirectoriesChanged(
        _ paths: Set<String>,
        prefetchPaths: Set<String> = []
    ) {
        visibilityWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.applyVisibleDirectories(paths, prefetchPaths: prefetchPaths)
        }
        visibilityWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PanoramaMetrics.visibilityDebounce,
            execute: work
        )
    }

    // MARK: - Private

    private func applyVisibleDirectories(_ paths: Set<String>, prefetchPaths: Set<String>) {
        visibleDirectoryPaths = paths
        prefetchDirectoryPaths = prefetchPaths

        bootstrapper.boostVisiblePaths(
            dataSource: dataSource,
            collapseState: collapseState,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )
    }

    private func applyCellVisibility(_ snapshot: PanoramaVisibilitySnapshot) {
        visibleDirectoryPaths = snapshot.visibleDirectoryPaths
        if !dataSource.rootDirectoryPath.isEmpty {
            visibleDirectoryPaths.insert(dataSource.rootDirectoryPath)
        }
        prefetchDirectoryPaths = snapshot.prefetchDirectoryPaths

        bootstrapper.boostVisiblePaths(
            dataSource: dataSource,
            collapseState: collapseState,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )

        updateThumbnailScheduler(visibleRowIDs: snapshot.visibleRowIDs)
    }

    private func updateThumbnailScheduler(visibleRowIDs: Set<String>) {
        let request = PanoramaThumbnailLoadRequest(
            orderedRowIDs: thumbnailCatalog.orderedRowIDs,
            rowsByID: thumbnailCatalog.rowsByID,
            visibleRowIDs: visibleRowIDs,
            cellSize: thumbnailCellSize,
            screenScale: thumbnailScreenScale,
            preferWorkspaceIcons: preferWorkspaceIconsInThumbnail
        )
        thumbnailScheduler.update(request)
    }

    private func handleListingDidUpdate(path: String) {
        rebuildDisplay()
        bootstrapper.listingDidUpdate(
            path: path,
            dataSource: dataSource,
            collapseState: collapseState,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )
    }

    private func rebuildDisplay() {
        let snapshot = PanoramaTreeDisplayBuilder.Snapshot(
            dataSource: dataSource,
            collapseState: collapseState
        )
        displayRoot = PanoramaTreeDisplayBuilder.build(snapshot: snapshot)
        thumbnailCatalog = PanoramaThumbnailCatalogBuilder.build(from: displayRoot)
        updateThumbnailScheduler(visibleRowIDs: cellTracker.snapshot.visibleRowIDs)
    }

    private func scheduleBootstrap() {
        bootstrapper.schedule(
            sessionGeneration: dataSource.generation,
            dataSource: dataSource,
            collapseState: collapseState,
            depthPolicy: depthPolicy,
            visibleDirectoryPaths: visibleDirectoryPaths,
            prefetchDirectoryPaths: prefetchDirectoryPaths
        )
    }

    /// 从根 listing、已加载子 listing 或节点缓存解析 `FileItem`。
    func fileItem(forRowID rowID: String, rootItems: [FileItem]) -> FileItem? {
        if let item = rootItems.first(where: { $0.id == rowID }) {
            return item
        }
        if let node = dataSource.node(for: rowID) {
            return node.item
        }
        if let rootLoaded = dataSource.loadedItems(for: dataSource.rootDirectoryPath),
           let item = rootLoaded.first(where: { $0.id == rowID }) {
            return item
        }
        for node in dataSource.allNodes {
            if let loaded = node.listing.loadedItems,
               let item = loaded.first(where: { $0.id == rowID }) {
                return item
            }
        }
        return nil
    }
}
