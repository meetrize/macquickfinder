import AppKit
import SwiftUI

/// 缩略图网格 NSCollectionView 宿主。
public struct FileListThumbnailHost: NSViewRepresentable {
    public let rows: [FileListRow]
    public let interaction: FileListTableInteraction
    @Binding public var selection: Set<String>
    @ObservedObject public var preferencesStore: FileListPreferencesStore
    public let cellSize: CGFloat
    public var onCellSizeChange: ((CGFloat) -> Void)?
    public let onOpenRow: (FileListRow) -> Void
    public var onVisibleDirectoryPathsChanged: (([String]) -> Void)?
    public var directorySizeProvider: DirectorySizeColumnProvider?
    
    public init(
        rows: [FileListRow],
        interaction: FileListTableInteraction,
        selection: Binding<Set<String>>,
        preferencesStore: FileListPreferencesStore,
        cellSize: CGFloat,
        onCellSizeChange: ((CGFloat) -> Void)? = nil,
        onOpenRow: @escaping (FileListRow) -> Void,
        onVisibleDirectoryPathsChanged: (([String]) -> Void)? = nil,
        directorySizeProvider: DirectorySizeColumnProvider? = nil
    ) {
        self.rows = rows
        self.interaction = interaction
        _selection = selection
        self.preferencesStore = preferencesStore
        self.cellSize = cellSize
        self.onCellSizeChange = onCellSizeChange
        self.onOpenRow = onOpenRow
        self.onVisibleDirectoryPathsChanged = onVisibleDirectoryPathsChanged
        self.directorySizeProvider = directorySizeProvider
    }
    
    public func makeCoordinator() -> FileListThumbnailController {
        let controller = FileListThumbnailController()
        controller.onOpenRow = onOpenRow
        controller.onCellSizeChange = onCellSizeChange
        controller.onVisibleDirectoryPathsChanged = onVisibleDirectoryPathsChanged
        return controller
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.makeScrollView()
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator
        controller.onOpenRow = onOpenRow
        controller.onCellSizeChange = onCellSizeChange
        controller.onVisibleDirectoryPathsChanged = onVisibleDirectoryPathsChanged
        controller.update(
            rows: rows,
            interaction: interaction,
            selectionGet: { selection },
            selectionSet: { selection = $0 },
            preferencesStore: preferencesStore,
            cellSize: cellSize
        )
        controller.refreshDirectorySizeColumnIfNeeded(directorySizeProvider)
    }
}
