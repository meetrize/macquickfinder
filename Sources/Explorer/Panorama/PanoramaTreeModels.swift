import FileList
import Foundation

// MARK: - Directory tree

struct PanoramaDirectoryID: Hashable, Sendable {
    let path: String

    init(path: String) {
        self.path = path
    }
}

enum PanoramaListingState: Equatable, Sendable {
    case unloaded
    case loading
    case loaded([FileItem])
    case failed(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var loadedItems: [FileItem]? {
        if case let .loaded(items) = self { return items }
        return nil
    }

    var itemCount: Int? {
        switch self {
        case .unloaded, .loading:
            return nil
        case let .loaded(items):
            return items.count
        case .failed:
            return nil
        }
    }
}

struct PanoramaDirectoryNode: Identifiable, Equatable, Sendable {
    let id: PanoramaDirectoryID
    let item: FileItem
    let depth: Int
    var listing: PanoramaListingState
    /// 父 listing 已加载时可用的子目录数量提示。
    var childCountHint: Int?

    var path: String { id.path }

    init(
        item: FileItem,
        depth: Int,
        listing: PanoramaListingState = .unloaded,
        childCountHint: Int? = nil
    ) {
        self.id = PanoramaDirectoryID(path: item.id)
        self.item = item
        self.depth = max(0, depth)
        self.listing = listing
        self.childCountHint = childCountHint
    }
}

// MARK: - Display model

enum PanoramaGridItem: Identifiable, Equatable, Sendable {
    case file(FileListRow)
    case folderCollapsed(FileListRow)
    case overflow(directoryID: String, remaining: Int)

    var id: String {
        switch self {
        case let .file(row), let .folderCollapsed(row):
            return row.id
        case let .overflow(directoryID, remaining):
            return "overflow:\(directoryID):\(remaining)"
        }
    }

    var rowID: String? {
        switch self {
        case let .file(row), let .folderCollapsed(row):
            return row.id
        case .overflow:
            return nil
        }
    }
}

enum PanoramaDisplayBlock: Identifiable, Equatable, Sendable {
    /// 展开目录：正常缩略图格 + 下方缩进子树。
    case expandedFolderSection(row: FileListRow, blocks: [PanoramaDisplayBlock])
    /// `gridInstanceID` 区分同一父目录下多段网格（避免 SwiftUI ForEach id 冲突）。
    case itemGrid(depth: Int, directoryID: String, gridInstanceID: String, items: [PanoramaGridItem])
    case childBlocks(parentDirectoryID: String, blocks: [PanoramaDisplayBlock])

    var id: String {
        switch self {
        case let .expandedFolderSection(row, _):
            return "expanded:\(row.id)"
        case let .itemGrid(_, directoryID, gridInstanceID, _):
            return "grid:\(directoryID):\(gridInstanceID)"
        case let .childBlocks(parentDirectoryID, _):
            return "children:\(parentDirectoryID)"
        }
    }

    var directoryID: String? {
        switch self {
        case let .expandedFolderSection(row, _):
            return row.id
        case let .itemGrid(_, directoryID, _, _):
            return directoryID
        case let .childBlocks(parentDirectoryID, _):
            return parentDirectoryID
        }
    }
}

/// 根目录全景展示快照（由 DisplayBuilder 产出）。
struct PanoramaDisplayRoot: Equatable, Sendable {
    let rootDirectoryPath: String
    let blocks: [PanoramaDisplayBlock]

    init(rootDirectoryPath: String, blocks: [PanoramaDisplayBlock]) {
        self.rootDirectoryPath = rootDirectoryPath
        self.blocks = blocks
    }
}
