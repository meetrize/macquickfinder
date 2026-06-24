import AppKit
import SwiftUI

/// 文件列表右侧空白区：单击取消选择、双击、右键菜单、纵向框选。
public struct FileListBlankAreaView: NSViewRepresentable {
    public let rowCount: Int
    public let rowID: (Int) -> String?
    @Binding public var selection: Set<String>
    public let menuActions: FileListBlankMenuActions
    public let onSingleClick: () -> Void
    public let onDoubleClick: () -> Void
    
    public init(
        rowCount: Int,
        rowID: @escaping (Int) -> String?,
        selection: Binding<Set<String>>,
        menuActions: FileListBlankMenuActions,
        onSingleClick: @escaping () -> Void,
        onDoubleClick: @escaping () -> Void
    ) {
        self.rowCount = rowCount
        self.rowID = rowID
        _selection = selection
        self.menuActions = menuActions
        self.onSingleClick = onSingleClick
        self.onDoubleClick = onDoubleClick
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(
            rowCount: rowCount,
            rowID: rowID,
            selection: $selection,
            menuActions: menuActions,
            onSingleClick: onSingleClick,
            onDoubleClick: onDoubleClick
        )
    }
    
    public func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.coordinator = context.coordinator
        return view
    }
    
    public func updateNSView(_ nsView: CaptureView, context: Context) {
        context.coordinator.rowCount = rowCount
        context.coordinator.rowID = rowID
        context.coordinator.selection = $selection
        context.coordinator.menuActions = menuActions
        context.coordinator.onSingleClick = onSingleClick
        context.coordinator.onDoubleClick = onDoubleClick
        nsView.coordinator = context.coordinator
    }
    
    public final class Coordinator: NSObject {
        var rowCount: Int
        var rowID: (Int) -> String?
        var selection: Binding<Set<String>>
        private let menuController: FileListBlankMenuController
        var menuActions: FileListBlankMenuActions {
            didSet { menuController.actions = menuActions }
        }
        var onSingleClick: () -> Void
        var onDoubleClick: () -> Void
        
        init(
            rowCount: Int,
            rowID: @escaping (Int) -> String?,
            selection: Binding<Set<String>>,
            menuActions: FileListBlankMenuActions,
            onSingleClick: @escaping () -> Void,
            onDoubleClick: @escaping () -> Void
        ) {
            self.rowCount = rowCount
            self.rowID = rowID
            self.selection = selection
            self.menuActions = menuActions
            self.menuController = FileListBlankMenuController(actions: menuActions)
            self.onSingleClick = onSingleClick
            self.onDoubleClick = onDoubleClick
        }
        
        func applyRowSelection(_ rows: IndexSet, tableView: NSTableView) {
            let ids = Set(
                rows.compactMap { row -> String? in
                    guard row >= 0, row < rowCount else { return nil }
                    return rowID(row)
                }
            )
            selection.wrappedValue = ids
            tableView.selectRowIndexes(rows, byExtendingSelection: false)
        }
        
        func popUpContextMenu(with event: NSEvent, for view: NSView) {
            menuController.popUp(with: event, for: view)
        }
    }
    
    public final class CaptureView: NSView {
        weak var coordinator: Coordinator?
        private weak var tableView: NSTableView?
        private var mouseDownEvent: NSEvent?
        private var isDragSelecting = false
        private let dragThreshold: CGFloat = 4
        
        public override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }
        
        public override func mouseDown(with event: NSEvent) {
            guard let coordinator else { return }
            if event.clickCount >= 2 {
                mouseDownEvent = nil
                isDragSelecting = false
                coordinator.onDoubleClick()
                return
            }
            mouseDownEvent = event
            isDragSelecting = false
            coordinator.onSingleClick()
        }
        
        public override func mouseDragged(with event: NSEvent) {
            guard let coordinator, let mouseDownEvent else { return }
            if !isDragSelecting {
                let deltaX = event.locationInWindow.x - mouseDownEvent.locationInWindow.x
                let deltaY = event.locationInWindow.y - mouseDownEvent.locationInWindow.y
                guard hypot(deltaX, deltaY) >= dragThreshold else { return }
                guard resolveTableView() != nil else { return }
                isDragSelecting = true
            }
            guard let tableView else { return }
            window?.makeFirstResponder(tableView)
            let startY = tableView.convert(mouseDownEvent.locationInWindow, from: nil).y
            let currentY = tableView.convert(event.locationInWindow, from: nil).y
            let rows = FileListInteractionCoordinator.rowsInVerticalRange(
                minY: startY,
                maxY: currentY,
                in: tableView
            )
            coordinator.applyRowSelection(rows, tableView: tableView)
        }
        
        public override func mouseUp(with event: NSEvent) {
            mouseDownEvent = nil
            isDragSelecting = false
        }
        
        public override func rightMouseDown(with event: NSEvent) {
            coordinator?.popUpContextMenu(with: event, for: self)
        }
        
        private func resolveTableView() -> NSTableView? {
            if let tableView { return tableView }
            guard let sibling = superview?.subviews.first(where: { $0 !== self }) else {
                return findTableView(startingFrom: window?.contentView)
            }
            let found = findTableView(startingFrom: sibling) ?? findTableView(startingFrom: window?.contentView)
            tableView = found
            return found
        }
        
        private func findTableView(startingFrom view: NSView?) -> NSTableView? {
            guard let view else { return nil }
            if let tableView = view as? NSTableView {
                return tableView
            }
            for subview in view.subviews {
                if let tableView = findTableView(startingFrom: subview) {
                    return tableView
                }
            }
            return nil
        }
    }
}
