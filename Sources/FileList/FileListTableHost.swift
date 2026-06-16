import AppKit
import SwiftUI

/// 文件列表 NSTableView 宿主（替代 SwiftUI `Table`）。
public struct FileListTableHost: NSViewRepresentable {
    public let rows: [FileListRow]
    public let interaction: FileListTableInteraction
    @Binding public var selection: Set<String>
    @ObservedObject public var preferencesStore: FileListPreferencesStore
    public let onOpenRow: (FileListRow) -> Void
    
    public init(
        rows: [FileListRow],
        interaction: FileListTableInteraction,
        selection: Binding<Set<String>>,
        preferencesStore: FileListPreferencesStore,
        onOpenRow: @escaping (FileListRow) -> Void
    ) {
        self.rows = rows
        self.interaction = interaction
        _selection = selection
        self.preferencesStore = preferencesStore
        self.onOpenRow = onOpenRow
    }
    
    public func makeCoordinator() -> FileListTableController {
        let controller = FileListTableController()
        controller.onOpenRow = onOpenRow
        return controller
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.makeScrollView()
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator
        controller.onOpenRow = onOpenRow
        controller.update(
            rows: rows,
            interaction: interaction,
            selectionGet: { selection },
            selectionSet: { selection = $0 },
            preferencesStore: preferencesStore
        )
    }
}
