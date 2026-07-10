import FileList
import SwiftUI

struct PanoramaFolderSectionView: View {
    let blocks: [PanoramaDisplayBlock]
    let cellSize: CGFloat
    let viewportWidth: CGFloat
    let selection: Set<String>
    let rowHoverHighlight: Bool
    let imageForRow: (String) -> NSImage?
    let onCollapse: (String) -> Void
    let onEnterDirectory: (String) -> Void
    let onTap: (FileListRow) -> Void
    let onCommandTap: (FileListRow) -> Void
    let onDoubleTap: (FileListRow) -> Void
    let onExpandCollapsedFolder: (FileListRow) -> Void

    var body: some View {
        ForEach(blocks) { block in
            blockView(for: block)
                .id(block.id)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func blockView(for block: PanoramaDisplayBlock) -> some View {
        switch block {
        case let .expandedFolderSection(row, childBlocks):
            VStack(alignment: .leading, spacing: PanoramaMetrics.sectionVerticalSpacing) {
                PanoramaLeadingInsetRow(depth: row.depth) {
                    PanoramaGridCellView(
                        row: row,
                        image: imageForRow(row.id),
                        cellSize: cellSize,
                        isSelected: selection.contains(row.id),
                        isCollapsedFolder: false,
                        isExpandedFolder: true,
                        rowHoverHighlight: rowHoverHighlight,
                        onTap: { onTap(row) },
                        onCommandTap: { onCommandTap(row) },
                        onDoubleTap: { onEnterDirectory(row.id) },
                        onCollapseFolder: { onCollapse(row.id) }
                    )
                    .panoramaCellVisibility(rowID: row.id, directoryID: row.id)
                }

                if !childBlocks.isEmpty {
                    PanoramaFolderSectionView(
                        blocks: childBlocks,
                        cellSize: cellSize,
                        viewportWidth: viewportWidth,
                        selection: selection,
                        rowHoverHighlight: rowHoverHighlight,
                        imageForRow: imageForRow,
                        onCollapse: onCollapse,
                        onEnterDirectory: onEnterDirectory,
                        onTap: onTap,
                        onCommandTap: onCommandTap,
                        onDoubleTap: onDoubleTap,
                        onExpandCollapsedFolder: onExpandCollapsedFolder
                    )
                }
            }

        case let .childBlocks(_, nestedBlocks):
            PanoramaFolderSectionView(
                blocks: nestedBlocks,
                cellSize: cellSize,
                viewportWidth: viewportWidth,
                selection: selection,
                rowHoverHighlight: rowHoverHighlight,
                imageForRow: imageForRow,
                onCollapse: onCollapse,
                onEnterDirectory: onEnterDirectory,
                onTap: onTap,
                onCommandTap: onCommandTap,
                onDoubleTap: onDoubleTap,
                onExpandCollapsedFolder: onExpandCollapsedFolder
            )

        case let .itemGrid(depth, directoryID, _, items):
            PanoramaItemGridView(
                depth: depth,
                directoryID: directoryID,
                items: items,
                cellSize: cellSize,
                viewportWidth: viewportWidth,
                selection: selection,
                rowHoverHighlight: rowHoverHighlight,
                imageForRow: imageForRow,
                onTap: onTap,
                onCommandTap: onCommandTap,
                onDoubleTap: onDoubleTap,
                onEnterDirectory: onEnterDirectory,
                onExpandCollapsedFolder: onExpandCollapsedFolder
            )
        }
    }
}
