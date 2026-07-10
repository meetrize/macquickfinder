import FileList
import SwiftUI

struct PanoramaItemGridView: View {
    let depth: Int
    let directoryID: String
    let items: [PanoramaGridItem]
    let cellSize: CGFloat
    let viewportWidth: CGFloat
    let selection: Set<String>
    let rowHoverHighlight: Bool
    let imageForRow: (String) -> NSImage?
    let onTap: (FileListRow) -> Void
    let onCommandTap: (FileListRow) -> Void
    let onDoubleTap: (FileListRow) -> Void
    let onEnterDirectory: (String) -> Void
    let onExpandCollapsedFolder: (FileListRow) -> Void

    private var gridColumns: [GridItem] {
        let availableWidth = PanoramaMetrics.gridAvailableWidth(
            viewportWidth: viewportWidth,
            depth: depth
        )
        let columnCount = PanoramaMetrics.gridColumnCount(
            availableWidth: availableWidth,
            cellSize: cellSize
        )
        return Array(
            repeating: GridItem(.fixed(cellSize), spacing: PanoramaMetrics.gridSpacing, alignment: .top),
            count: columnCount
        )
    }

    var body: some View {
        PanoramaLeadingInsetRow(depth: depth) {
            LazyVGrid(
                columns: gridColumns,
                alignment: .leading,
                spacing: PanoramaMetrics.gridSpacing
            ) {
                ForEach(items) { item in
                    gridCell(for: item)
                }
            }
        }
        .frame(height: estimatedHeight, alignment: .top)
    }

    private var estimatedHeight: CGFloat {
        guard !items.isEmpty else { return 0 }
        let availableWidth = PanoramaMetrics.gridAvailableWidth(
            viewportWidth: max(viewportWidth, cellSize),
            depth: depth
        )
        let columnCount = max(
            1,
            PanoramaMetrics.gridColumnCount(availableWidth: availableWidth, cellSize: cellSize)
        )
        let rowCount = Int(ceil(Double(items.count) / Double(columnCount)))
        return CGFloat(rowCount) * cellSize + CGFloat(max(0, rowCount - 1)) * PanoramaMetrics.gridSpacing
    }

    @ViewBuilder
    private func gridCell(for item: PanoramaGridItem) -> some View {
        switch item {
        case let .file(row):
            cell(for: row, isCollapsedFolder: false)
        case let .folderCollapsed(row):
            cell(for: row, isCollapsedFolder: true)
        case let .overflow(_, remaining):
            PanoramaOverflowCellView(remaining: remaining, cellSize: cellSize) {
                onEnterDirectory(directoryID)
            }
            .panoramaCellVisibility(
                rowID: "overflow:\(directoryID)",
                directoryID: directoryID
            )
        }
    }

    private func cell(for row: FileListRow, isCollapsedFolder: Bool) -> some View {
        PanoramaGridCellView(
            row: row,
            image: imageForRow(row.id),
            cellSize: cellSize,
            isSelected: selection.contains(row.id),
            isCollapsedFolder: isCollapsedFolder,
            isExpandedFolder: false,
            rowHoverHighlight: rowHoverHighlight,
            onTap: { onTap(row) },
            onCommandTap: { onCommandTap(row) },
            onDoubleTap: {
                if isCollapsedFolder {
                    onExpandCollapsedFolder(row)
                } else {
                    onDoubleTap(row)
                }
            },
            onCollapseFolder: nil
        )
        .panoramaCellVisibility(
            rowID: row.id,
            directoryID: directoryID
        )
    }
}
