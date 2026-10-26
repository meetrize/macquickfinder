import AppKit
import SwiftUI

/// 文件列表 NSTableView 宿主（替代 SwiftUI `Table`）。
public struct FileListTableHost: NSViewRepresentable {
    public let rows: [FileListRow]
    public let interaction: FileListTableInteraction
    @Binding public var selection: Set<String>
    @ObservedObject public var preferencesStore: FileListPreferencesStore
    public let onOpenRow: (FileListRowOpenIntent) -> Void
    public var onVisibleDirectoryPathsChanged: (([String]) -> Void)?
    public var directorySizeProvider: DirectorySizeColumnProvider?
    public var useIconPreview: Bool
    public var rowHoverHighlight: Bool
    public var onHoverRowChange: ((FileListRow?, NSView?) -> Void)?
    
    public init(
        rows: [FileListRow],
        interaction: FileListTableInteraction,
        selection: Binding<Set<String>>,
        preferencesStore: FileListPreferencesStore,
        onOpenRow: @escaping (FileListRowOpenIntent) -> Void,
        onVisibleDirectoryPathsChanged: (([String]) -> Void)? = nil,
        directorySizeProvider: DirectorySizeColumnProvider? = nil,
        useIconPreview: Bool = false,
        rowHoverHighlight: Bool = false,
        onHoverRowChange: ((FileListRow?, NSView?) -> Void)? = nil
    ) {
        self.rows = rows
        self.interaction = interaction
        _selection = selection
        self.preferencesStore = preferencesStore
        self.onOpenRow = onOpenRow
        self.onVisibleDirectoryPathsChanged = onVisibleDirectoryPathsChanged
        self.directorySizeProvider = directorySizeProvider
        self.useIconPreview = useIconPreview
        self.rowHoverHighlight = rowHoverHighlight
        self.onHoverRowChange = onHoverRowChange
    }
    
    public func makeCoordinator() -> FileListTableController {
        let controller = FileListTableController()
        FileListContentHostSupport.wireCallbacks(
            controller,
            onOpenRow: onOpenRow,
            onVisibleDirectoryPathsChanged: onVisibleDirectoryPathsChanged,
            onHoverRowChange: onHoverRowChange
        )
        return controller
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.makeScrollView()
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator
        FileListContentHostSupport.wireCallbacks(
            controller,
            onOpenRow: onOpenRow,
            onVisibleDirectoryPathsChanged: onVisibleDirectoryPathsChanged,
            onHoverRowChange: onHoverRowChange
        )
        controller.update(
            rows: rows,
            interaction: interaction,
            selectionGet: { selection },
            selectionSet: { selection = $0 },
            preferencesStore: preferencesStore,
            useIconPreview: useIconPreview,
            rowHoverHighlight: rowHoverHighlight
        )
        controller.syncRowHoverTrackingEnabled()
        controller.refreshDirectorySizeColumnIfNeeded(directorySizeProvider)
    }
}
