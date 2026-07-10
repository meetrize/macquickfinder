import FileList
import Foundation

/// 子目录全景 listing + 收起状态 → 展示块树。
enum PanoramaTreeDisplayBuilder {
    struct Snapshot: Equatable, Sendable {
        let rootDirectoryPath: String
        let rootListing: PanoramaListingState
        let nodesByPath: [String: PanoramaDirectoryNode]
        let collapseState: PanoramaTreeCollapseState

        init(
            rootDirectoryPath: String,
            rootListing: PanoramaListingState,
            nodesByPath: [String: PanoramaDirectoryNode],
            collapseState: PanoramaTreeCollapseState
        ) {
            self.rootDirectoryPath = rootDirectoryPath
            self.rootListing = rootListing
            self.nodesByPath = nodesByPath
            self.collapseState = collapseState
        }

        @MainActor
        init(dataSource: PanoramaTreeDataSource, collapseState: PanoramaTreeCollapseState) {
            self.init(
                rootDirectoryPath: dataSource.rootDirectoryPath,
                rootListing: dataSource.rootListing,
                nodesByPath: Dictionary(
                    uniqueKeysWithValues: dataSource.allNodes.map { ($0.path, $0) }
                ),
                collapseState: collapseState
            )
        }
    }

    static func build(snapshot: Snapshot) -> PanoramaDisplayRoot {
        guard case let .loaded(rootItems) = snapshot.rootListing else {
            return PanoramaDisplayRoot(rootDirectoryPath: snapshot.rootDirectoryPath, blocks: [])
        }

        let blocks = buildSiblingBlocks(
            items: rootItems,
            contentDepth: 0,
            gridDirectoryID: snapshot.rootDirectoryPath,
            parentDirectoryID: snapshot.rootDirectoryPath,
            ancestorDirectoryIDs: [],
            snapshot: snapshot
        )

        return PanoramaDisplayRoot(
            rootDirectoryPath: snapshot.rootDirectoryPath,
            blocks: blocks
        )
    }

    // MARK: - Sibling layout (sort-order preserved)

    /// 按 listing 顺序构建同级内容：目录保持全局排序，展开块与网格块交错。
    private static func buildSiblingBlocks(
        items: [FileItem],
        contentDepth: Int,
        gridDirectoryID: String,
        parentDirectoryID: String,
        ancestorDirectoryIDs: [String],
        snapshot: Snapshot
    ) -> [PanoramaDisplayBlock] {
        var blocks: [PanoramaDisplayBlock] = []
        var pendingCollapsedFolders: [FileListRow] = []
        var pendingFiles: [FileListRow] = []

        func flushGridIfNeeded() {
            guard let grid = makeGridBlock(
                depth: contentDepth,
                directoryID: gridDirectoryID,
                collapsedFolders: pendingCollapsedFolders,
                files: pendingFiles
            ) else { return }
            blocks.append(grid)
            pendingCollapsedFolders = []
            pendingFiles = []
        }

        for item in items {
            if item.isDirectory {
                if shouldRenderExpandedSection(
                    for: item,
                    depth: contentDepth,
                    parentDirectoryID: parentDirectoryID,
                    snapshot: snapshot,
                    ancestorDirectoryIDs: ancestorDirectoryIDs
                ) {
                    flushGridIfNeeded()
                    blocks.append(
                        contentsOf: buildExpandedDirectoryBlocks(
                            item: item,
                            depth: contentDepth,
                            parentDirectoryID: parentDirectoryID,
                            ancestorDirectoryIDs: ancestorDirectoryIDs,
                            snapshot: snapshot
                        )
                    )
                } else {
                    pendingCollapsedFolders.append(
                        makeRow(
                            item: item,
                            depth: contentDepth,
                            parentDirectoryID: parentDirectoryID,
                            snapshot: snapshot
                        )
                    )
                }
            } else {
                pendingFiles.append(
                    makeRow(
                        item: item,
                        depth: contentDepth,
                        parentDirectoryID: parentDirectoryID,
                        snapshot: snapshot
                    )
                )
            }
        }

        flushGridIfNeeded()
        return blocks
    }

    // MARK: - Expanded directory

    private static func buildExpandedDirectoryBlocks(
        item: FileItem,
        depth: Int,
        parentDirectoryID: String,
        ancestorDirectoryIDs: [String],
        snapshot: Snapshot
    ) -> [PanoramaDisplayBlock] {
        let listing = listing(for: item.id, snapshot: snapshot)
        let row = makeRow(
            item: item,
            depth: depth,
            parentDirectoryID: parentDirectoryID,
            snapshot: snapshot
        )

        guard case let .loaded(children) = listing else {
            return [.expandedFolderSection(row: row, blocks: [])]
        }

        let ancestors = ancestorDirectoryIDs + [item.id]
        let innerBlocks = buildSiblingBlocks(
            items: children,
            contentDepth: depth + 1,
            gridDirectoryID: item.id,
            parentDirectoryID: item.id,
            ancestorDirectoryIDs: ancestors,
            snapshot: snapshot
        )

        return [.expandedFolderSection(row: row, blocks: innerBlocks)]
    }

    private static func makeGridBlock(
        depth: Int,
        directoryID: String,
        collapsedFolders: [FileListRow],
        files: [FileListRow]
    ) -> PanoramaDisplayBlock? {
        let gridItems = PanoramaMetrics.cappedGridItems(
            files: files,
            collapsedFolders: collapsedFolders,
            directoryID: directoryID
        )
        guard let gridInstanceID = gridItems.first?.id else { return nil }
        return .itemGrid(
            depth: depth,
            directoryID: directoryID,
            gridInstanceID: gridInstanceID,
            items: gridItems
        )
    }

    // MARK: - Helpers

    private static func shouldRenderExpandedSection(
        for item: FileItem,
        depth: Int,
        parentDirectoryID: String,
        snapshot: Snapshot,
        ancestorDirectoryIDs: [String] = []
    ) -> Bool {
        guard item.isDirectory else { return false }
        guard snapshot.collapseState.isExpanded(item.id) else { return false }
        guard snapshot.collapseState.isSubtreeVisible(
            for: item.id,
            ancestorIDs: ancestorDirectoryIDs
        ) else { return false }
        return directoryShowsExpandedSection(for: item.id, snapshot: snapshot)
    }

    private static func directoryShowsExpandedSection(for path: String, snapshot: Snapshot) -> Bool {
        switch listing(for: path, snapshot: snapshot) {
        case let .loaded(items):
            return !items.isEmpty
        case .failed, .loading, .unloaded:
            return true
        }
    }

    private static func listing(for path: String, snapshot: Snapshot) -> PanoramaListingState {
        if path == snapshot.rootDirectoryPath {
            return snapshot.rootListing
        }
        return snapshot.nodesByPath[path]?.listing ?? .unloaded
    }

    private static func makeRow(
        item: FileItem,
        depth: Int,
        parentDirectoryID: String,
        snapshot: Snapshot
    ) -> FileListRow {
        let listing = listing(for: item.id, snapshot: snapshot)
        let childCountDisplay: DirectoryItemCountDisplayInfo?
        if item.isDirectory {
            switch listing {
            case let .loaded(items):
                childCountDisplay = .formatted(items.count)
            case .unloaded, .loading:
                childCountDisplay = snapshot.nodesByPath[item.id]?.childCountHint.map(DirectoryItemCountDisplayInfo.formatted)
            case .failed:
                childCountDisplay = nil
            }
        } else {
            childCountDisplay = nil
        }

        return FileListRow(
            item: item,
            directorySizeDisplay: nil,
            childCountDisplay: childCountDisplay,
            depth: depth,
            parentID: parentDirectoryID,
            isExpandable: item.isDirectory && !item.isParentDirectoryEntry,
            isExpanded: snapshot.collapseState.isExpanded(item.id),
            isExpanding: listing == .loading,
            expandErrorMessage: failedMessage(for: item.id, snapshot: snapshot)
        )
    }

    private static func failedMessage(for path: String, snapshot: Snapshot) -> String? {
        if case let .failed(message) = listing(for: path, snapshot: snapshot) {
            return message
        }
        return nil
    }
}
