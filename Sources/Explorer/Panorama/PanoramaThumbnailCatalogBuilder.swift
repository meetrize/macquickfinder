import CoreGraphics
import FileList
import Foundation

/// 从展示树提取缩略图加载目录（按视觉顺序）。
enum PanoramaThumbnailCatalogBuilder {
    struct Catalog: Equatable, Sendable {
        let orderedRowIDs: [String]
        let rowsByID: [String: FileListRow]
        let directoryIDByRowID: [String: String]
    }

    static func build(from displayRoot: PanoramaDisplayRoot) -> Catalog {
        var orderedRowIDs: [String] = []
        var rowsByID: [String: FileListRow] = [:]
        var directoryIDByRowID: [String: String] = [:]

        func appendGridItems(_ items: [PanoramaGridItem], directoryID: String) {
            for item in items {
                switch item {
                case let .file(row), let .folderCollapsed(row):
                    guard rowsByID[row.id] == nil else { continue }
                    orderedRowIDs.append(row.id)
                    rowsByID[row.id] = row
                    directoryIDByRowID[row.id] = directoryID
                case .overflow:
                    continue
                }
            }
        }

        func walk(_ blocks: [PanoramaDisplayBlock]) {
            for block in blocks {
                switch block {
                case let .expandedFolderSection(row, children):
                    if rowsByID[row.id] == nil {
                        orderedRowIDs.append(row.id)
                        rowsByID[row.id] = row
                        directoryIDByRowID[row.id] = row.id
                    }
                    walk(children)
                case let .itemGrid(_, directoryID, _, items):
                    appendGridItems(items, directoryID: directoryID)
                case let .childBlocks(_, children):
                    walk(children)
                }
            }
        }

        walk(displayRoot.blocks)

        return Catalog(
            orderedRowIDs: orderedRowIDs,
            rowsByID: rowsByID,
            directoryIDByRowID: directoryIDByRowID
        )
    }
}
