import SwiftUI
import AppKit
import FileList

enum BarTextFieldID: Hashable {
    case path
    case search
}

/// 按窗口记录各输入框对应的 NSTextField，多窗口互不干扰。
enum BarTextFieldFocusRegistry {
    private final class WindowState {
        weak var pathField: NSTextField?
        weak var searchField: NSTextField?
        weak var pathBarRoot: NSView?
        weak var pathNavigateButton: NSView?
        weak var pathBarBlankClickArea: NSView?
        var pendingSelectAll: BarTextFieldID?
    }

    private static let states = NSMapTable<NSWindow, WindowState>.weakToStrongObjects()

    private static func state(for window: NSWindow) -> WindowState {
        if let existing = states.object(forKey: window) { return existing }
        let created = WindowState()
        states.setObject(created, forKey: window)
        return created
    }

    private static func state(for view: NSView) -> WindowState? {
        guard let window = view.window else { return nil }
        return state(for: window)
    }

    private static func field(for id: BarTextFieldID, in window: NSWindow) -> NSTextField? {
        let windowState = state(for: window)
        switch id {
        case .path: return windowState.pathField
        case .search: return windowState.searchField
        }
    }

    static func register(_ field: NSTextField, for id: BarTextFieldID) {
        guard let window = field.window else { return }
        let windowState = state(for: window)
        switch id {
        case .path: windowState.pathField = field
        case .search: windowState.searchField = field
        }
    }

    static func requestSelectAll(_ id: BarTextFieldID, in window: NSWindow) {
        state(for: window).pendingSelectAll = id
    }

    static func applyPendingSelectAll(for id: BarTextFieldID, in window: NSWindow) {
        let windowState = state(for: window)
        guard windowState.pendingSelectAll == id else { return }
        windowState.pendingSelectAll = nil
        selectAll(id, in: window)
    }

    static func clearPendingSelectAll(in window: NSWindow) {
        state(for: window).pendingSelectAll = nil
    }

    static func hasPendingSelectAll(_ id: BarTextFieldID, in window: NSWindow) -> Bool {
        state(for: window).pendingSelectAll == id
    }

    static func focus(_ id: BarTextFieldID, in window: NSWindow) {
        guard let field = field(for: id, in: window) else { return }
        window.makeFirstResponder(field)
    }

    static func selectAll(_ id: BarTextFieldID, in window: NSWindow) {
        if id == .path, let field = field(for: .path, in: window) as? PathBarTextField {
            field.prepareSelectAllOnFocus()
            field.selectAllText()
            return
        }
        guard let field = field(for: id, in: window) else { return }
        if field.currentEditor() == nil {
            field.selectText(nil)
        }
        if let editor = field.currentEditor() {
            window.makeFirstResponder(editor)
            editor.selectAll(nil)
        } else {
            window.makeFirstResponder(field)
            field.selectText(nil)
            field.currentEditor()?.selectAll(nil)
        }
    }

    /// 聚焦路径/搜索框并立刻全选；若 field editor 尚未就绪则短轮询补齐。
    static func focusAndSelectAll(_ id: BarTextFieldID, in window: NSWindow) {
        requestSelectAll(id, in: window)
        guard let field = field(for: id, in: window), field.window != nil else {
            focusWhenReady(id, in: window, selectAll: true)
            return
        }
        focus(id, in: window)
        if field.currentEditor() == nil {
            field.selectText(nil)
        }
        selectAll(id, in: window)
        guard hasActiveFieldEditor(field) else {
            focusWhenReady(id, in: window, selectAll: true)
            return
        }
        DispatchQueue.main.async {
            selectAll(id, in: window)
        }
    }

    static func focusWhenReady(
        _ id: BarTextFieldID,
        in window: NSWindow,
        selectAll: Bool = false,
        onComplete: ((Bool) -> Void)? = nil,
        attempt: Int = 0
    ) {
        guard attempt < 30 else {
            onComplete?(false)
            return
        }
        guard let field = field(for: id, in: window), field.window != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                focusWhenReady(id, in: window, selectAll: selectAll, onComplete: onComplete, attempt: attempt + 1)
            }
            return
        }

        focus(id, in: window)
        if field.currentEditor() == nil {
            field.selectText(nil)
        }
        if let editor = field.currentEditor() {
            field.window?.makeFirstResponder(editor)
        }

        guard hasActiveFieldEditor(field) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                focusWhenReady(id, in: window, selectAll: selectAll, onComplete: onComplete, attempt: attempt + 1)
            }
            return
        }

        if selectAll {
            requestSelectAll(id, in: window)
            Self.selectAll(id, in: window)
            DispatchQueue.main.async {
                Self.selectAll(id, in: window)
                onComplete?(true)
            }
        } else {
            onComplete?(true)
        }
    }

    static func resign(_ id: BarTextFieldID, in window: NSWindow) {
        guard let field = field(for: id, in: window) else { return }
        guard isFieldEditing(field) else { return }
        window.makeFirstResponder(nil)
    }

    /// 结束 field editor，确保下次进入文本模式时 textDidBeginEditing 会再次触发。
    static func endEditing(_ id: BarTextFieldID, in window: NSWindow) {
        guard let field = field(for: id, in: window) else { return }
        if field.currentEditor() != nil {
            field.abortEditing()
        }
        window.makeFirstResponder(nil)
    }

    static func isClickInside(_ id: BarTextFieldID, event: NSEvent) -> Bool {
        guard let window = event.window,
              let field = field(for: id, in: window),
              let contentView = window.contentView,
              let hitView = contentView.hitTest(event.locationInWindow) else {
            return false
        }
        return hitView === field || hitView.isDescendant(of: field)
    }

    static func isClickInsideNavigateButton(event: NSEvent) -> Bool {
        guard let window = event.window,
              let button = state(for: window).pathNavigateButton,
              let contentView = window.contentView,
              let hitView = contentView.hitTest(event.locationInWindow) else {
            return false
        }
        return hitView === button || hitView.isDescendant(of: button)
    }

    static func isClickInsidePathBar(event: NSEvent) -> Bool {
        if isClickInsideNavigateButton(event: event) { return true }
        if isClickInside(.path, event: event) { return true }
        guard let window = event.window else { return false }
        let windowState = state(for: window)
        if isClickInsideRegisteredView(windowState.pathBarBlankClickArea, event: event) { return true }
        return isClickInsideRegisteredView(windowState.pathBarRoot, event: event)
    }

    static func registerPathBarRoot(_ view: NSView) {
        guard let windowState = state(for: view) else { return }
        windowState.pathBarRoot = view
    }

    static func registerPathNavigateButton(_ view: NSView) {
        guard let windowState = state(for: view) else { return }
        windowState.pathNavigateButton = view
    }

    static func registerPathBarBlankClickArea(_ view: NSView) {
        guard let windowState = state(for: view) else { return }
        windowState.pathBarBlankClickArea = view
    }

    private static func isClickInsideRegisteredView(_ view: NSView?, event: NSEvent) -> Bool {
        guard let view, view.window != nil else { return false }
        let point = view.convert(event.locationInWindow, from: nil)
        return view.bounds.contains(point)
    }

    static func currentEditingField(in window: NSWindow) -> BarTextFieldID? {
        let windowState = state(for: window)
        if let searchField = windowState.searchField, hasActiveFieldEditor(searchField) { return .search }
        if let pathField = windowState.pathField, hasActiveFieldEditor(pathField) { return .path }
        return nil
    }

    private static func hasActiveFieldEditor(_ field: NSTextField) -> Bool {
        guard let editor = field.currentEditor() else { return false }
        guard let window = field.window, let responder = window.firstResponder else { return false }
        if responder === editor { return true }
        if let view = responder as? NSView, view.isDescendant(of: editor) { return true }
        return false
    }

    private static func isFieldEditing(_ field: NSTextField) -> Bool {
        if hasActiveFieldEditor(field) { return true }
        guard let window = field.window, let responder = window.firstResponder else { return false }
        if responder === field { return field.currentEditor() != nil }
        if let view = responder as? NSView, view.isDescendant(of: field) { return true }
        return false
    }
}

/// 绑定当前 SwiftUI 视图所在的 NSWindow，供地址栏/搜索栏按窗口隔离焦点状态。
struct HostWindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?
    var onWindowAttached: ((NSWindow) -> Void)? = nil

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.onWindowChange = { newWindow in
            if let newWindow {
                onWindowAttached?(newWindow)
            }
            DispatchQueue.main.async {
                window = newWindow
            }
        }
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        nsView.reportWindow()
    }

    final class TrackerView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportWindow()
        }

        func reportWindow() {
            onWindowChange?(window)
        }
    }
}

/// 地址栏/搜索栏有焦点时，点击外部同步失焦；点击文件列表时在同一次点击中选中对应行。
struct BarFieldOutsideClickHandler: NSViewRepresentable {
    @Binding var activeField: BarTextFieldID?
    @Binding var isPathBarTextMode: Bool
    let tableItems: [FileItem]
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            activeField: $activeField,
            isPathBarTextMode: $isPathBarTextMode,
            tableItems: tableItems
        )
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.anchorView = view
        context.coordinator.start()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.anchorView = nsView
        context.coordinator.tableItems = tableItems
    }
    
    final class Coordinator {
        @Binding var activeField: BarTextFieldID?
        @Binding var isPathBarTextMode: Bool
        var tableItems: [FileItem]
        weak var anchorView: NSView?
        private var monitor: Any?
        
        init(
            activeField: Binding<BarTextFieldID?>,
            isPathBarTextMode: Binding<Bool>,
            tableItems: [FileItem]
        ) {
            _activeField = activeField
            _isPathBarTextMode = isPathBarTextMode
            self.tableItems = tableItems
        }
        
        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handleMouseDown(event)
                return event
            }
        }
        
        private func handleMouseDown(_ event: NSEvent) {
            guard let window = event.window else { return }
            guard window === anchorView?.window else { return }
            let editingField = BarTextFieldFocusRegistry.currentEditingField(in: window)
            let shouldDismissPathText = isPathBarTextMode
            guard editingField != nil || shouldDismissPathText else { return }
            
            if BarTextFieldFocusRegistry.isClickInsideNavigateButton(event: event) {
                return
            }
            
            if isPathBarTextMode,
               BarTextFieldFocusRegistry.isClickInsidePathBar(event: event)
                || BarTextFieldFocusRegistry.isClickInside(.path, event: event) {
                return
            }
            
            if let editingField, BarTextFieldFocusRegistry.isClickInside(editingField, event: event) {
                return
            }
            
            if let editingField {
                if shouldDismissPathText, editingField == .path {
                    BarTextFieldFocusRegistry.endEditing(.path, in: window)
                } else {
                    BarTextFieldFocusRegistry.resign(editingField, in: window)
                }
                if activeField == editingField {
                    activeField = nil
                }
            }
            
            if shouldDismissPathText {
                isPathBarTextMode = false
            }
            
            guard let tableView = tableView(at: event) else { return }
            guard let window = tableView.window ?? event.window else { return }
            
            if let headerView = tableView.headerView {
                let pointInHeader = headerView.convert(event.locationInWindow, from: nil)
                if headerView.bounds.contains(pointInHeader) {
                    return
                }
            }
            
            window.makeFirstResponder(tableView)
            
            let point = tableView.convert(event.locationInWindow, from: nil)
            let row = tableView.row(at: point)
            Self.selectRow(
                row,
                in: tableView,
                event: event,
                items: tableItems
            )
        }
        
        private func tableView(at event: NSEvent) -> NSTableView? {
            guard let window = event.window,
                  let contentView = window.contentView,
                  let hitView = contentView.hitTest(event.locationInWindow) else {
                return nil
            }
            return findTableView(from: hitView)
        }
        
        private func findTableView(from view: NSView) -> NSTableView? {
            var current: NSView? = view
            while let node = current {
                if let tableView = node as? NSTableView {
                    return tableView
                }
                current = node.superview
            }
            return nil
        }
        
        private static func selectRow(
            _ row: Int,
            in tableView: NSTableView,
            event: NSEvent,
            items: [FileItem]
        ) {
            guard row >= 0, row < items.count else {
                if row < 0 {
                    tableView.deselectAll(nil)
                }
                return
            }
            
            let item = items[row]
            let flags = event.modifierFlags
            
            if flags.contains(.command) {
                var selected = tableView.selectedRowIndexes
                if selected.contains(row) {
                    selected.remove(row)
                } else {
                    selected.insert(row)
                }
                tableView.selectRowIndexes(selected, byExtendingSelection: false)
                return
            }
            
            if flags.contains(.shift) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                return
            }
            
            var effectiveIDs = Set<FileItem.ID>()
            for selectedRow in tableView.selectedRowIndexes {
                guard selectedRow >= 0, selectedRow < items.count else { continue }
                let rowItem = items[selectedRow]
                guard !rowItem.isParentDirectoryEntry else { continue }
                effectiveIDs.insert(rowItem.id)
            }
            
            if effectiveIDs.contains(item.id) {
                return
            }
            
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// 根据当前 firstResponder 同步高亮状态，避免 SwiftUI FocusState 与工具栏输入框冲突。
struct BarTextFieldFocusSync: NSViewRepresentable {
    @Binding var activeField: BarTextFieldID?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(activeField: $activeField)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.anchorView = view
        context.coordinator.start()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.anchorView = nsView
        context.coordinator.syncFromResponder()
    }
    
    final class Coordinator {
        @Binding var activeField: BarTextFieldID?
        weak var anchorView: NSView?
        private var monitor: Any?
        
        init(activeField: Binding<BarTextFieldID?>) {
            _activeField = activeField
        }
        
        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
                if event.type == .leftMouseDown {
                    guard let self, event.window === self.anchorView?.window else { return event }
                    self.syncFromResponder(for: event.window)
                } else {
                    DispatchQueue.main.async {
                        self?.syncFromResponder(for: self?.anchorView?.window)
                    }
                }
                return event
            }
        }
        
        /// 仅在有真实 field editor 时提升 activeField，避免同一次点击把尚未完成的聚焦清回 nil。
        fileprivate func syncFromResponder(for eventWindow: NSWindow? = nil) {
            guard let window = eventWindow ?? anchorView?.window else { return }
            guard let current = BarTextFieldFocusRegistry.currentEditingField(in: window) else { return }
            guard activeField != current else { return }
            activeField = current
        }
        
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

enum BarTextFieldShape {
    case rounded
    case capsule
}

/// 工具栏内的 TextField 有时无法可靠同步 @FocusState，通过 NSTextField 编辑状态驱动边框高亮。
private struct BarTextFieldFocusObserver: NSViewRepresentable {
    let fieldID: BarTextFieldID
    @Binding var text: String
    @Binding var activeField: BarTextFieldID?
    var retainHighlight: Bool = false
    var clearTextOnEscape: Bool = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            fieldID: fieldID,
            text: $text,
            activeField: $activeField,
            clearTextOnEscape: clearTextOnEscape
        )
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        let wasRetainHighlight = context.coordinator.retainHighlight
        context.coordinator.text = $text
        context.coordinator.retainHighlight = retainHighlight
        context.coordinator.clearTextOnEscape = clearTextOnEscape
        context.coordinator.refreshEscapeMonitor()
        context.coordinator.refreshEditingState()
        if fieldID == .path, retainHighlight, !wasRetainHighlight,
           let window = context.coordinator.textField?.window {
            BarTextFieldFocusRegistry.applyPendingSelectAll(for: .path, in: window)
            BarTextFieldFocusRegistry.selectAll(.path, in: window)
        }
    }
    
    final class Coordinator {
        let fieldID: BarTextFieldID
        var text: Binding<String>
        @Binding var activeField: BarTextFieldID?
        var retainHighlight = false
        var clearTextOnEscape = false
        private weak var anchorView: NSView?
        fileprivate weak var textField: NSTextField?
        private var observers: [NSObjectProtocol] = []
        private var escapeMonitor: Any?
        private var retryCount = 0
        private var isHooked = false
        
        init(
            fieldID: BarTextFieldID,
            text: Binding<String>,
            activeField: Binding<BarTextFieldID?>,
            clearTextOnEscape: Bool
        ) {
            self.fieldID = fieldID
            self.text = text
            _activeField = activeField
            self.clearTextOnEscape = clearTextOnEscape
        }
        
        func attach(to view: NSView) {
            guard !isHooked else { return }
            anchorView = view
            retryCount = 0
            hookTextFieldIfNeeded()
        }
        
        private func hookTextFieldIfNeeded() {
            guard !isHooked, let anchorView else { return }
            
            guard let field = findAssociatedTextField(from: anchorView) else {
                guard retryCount < 20 else { return }
                retryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.hookTextFieldIfNeeded()
                }
                return
            }
            
            isHooked = true
            textField = field
            BarTextFieldFocusRegistry.register(field, for: fieldID)
            let center = NotificationCenter.default
            observers.append(
                center.addObserver(
                    forName: NSControl.textDidBeginEditingNotification,
                    object: field,
                    queue: .main
                ) { [weak self] _ in
                    guard let self else { return }
                    self.activateField()
                    if let window = self.textField?.window {
                        BarTextFieldFocusRegistry.applyPendingSelectAll(for: self.fieldID, in: window)
                    }
                }
            )
            observers.append(
                center.addObserver(
                    forName: NSControl.textDidEndEditingNotification,
                    object: field,
                    queue: .main
                ) { [weak self] _ in
                    self?.refreshEditingState()
                }
            )
            observers.append(
                center.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.refreshEditingState()
                }
            )
            refreshEditingState()
            refreshEscapeMonitor()
        }

        fileprivate func refreshEscapeMonitor() {
            guard clearTextOnEscape, isHooked else {
                removeEscapeMonitor()
                return
            }
            guard escapeMonitor == nil else { return }
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleEscapeKey(event) ?? event
            }
        }

        private func removeEscapeMonitor() {
            if let escapeMonitor {
                NSEvent.removeMonitor(escapeMonitor)
                self.escapeMonitor = nil
            }
        }

        private func handleEscapeKey(_ event: NSEvent) -> NSEvent? {
            guard event.keyCode == 53 else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.contains(.command), !flags.contains(.control), !flags.contains(.option) else {
                return event
            }
            guard let window = textField?.window, event.window === window else { return event }
            guard BarTextFieldFocusRegistry.currentEditingField(in: window) == fieldID else { return event }
            guard !text.wrappedValue.isEmpty else { return event }

            text.wrappedValue = ""
            textField?.stringValue = ""
            activeField = fieldID
            BarTextFieldFocusRegistry.focus(fieldID, in: window)
            return nil
        }
        
        private func activateField() {
            activeField = fieldID
        }
        
        private func deactivateFieldIfNeeded() {
            guard activeField == fieldID else { return }
            if let window = textField?.window {
                activeField = BarTextFieldFocusRegistry.currentEditingField(in: window)
            } else {
                activeField = nil
            }
        }
        
        fileprivate func refreshEditingState() {
            guard textField != nil else { return }
            if let window = textField?.window,
               BarTextFieldFocusRegistry.currentEditingField(in: window) == fieldID {
                activateField()
            } else if !retainHighlight {
                deactivateFieldIfNeeded()
            }
        }
        
        private func findAssociatedTextField(from anchor: NSView) -> NSTextField? {
            if let field = anchor as? NSTextField { return field }
            
            var current: NSView? = anchor
            while let node = current {
                for subview in node.subviews {
                    guard subview === anchor || anchor.isDescendant(of: subview) else { continue }
                    if let field = subview as? NSTextField { return field }
                    if let field = findTextField(in: subview) { return field }
                }
                current = node.superview
            }
            return nil
        }
        
        private func findTextField(in view: NSView) -> NSTextField? {
            if let field = view as? NSTextField { return field }
            for subview in view.subviews {
                if let field = findTextField(in: subview) { return field }
            }
            return nil
        }
        
        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            removeEscapeMonitor()
        }
    }
}

struct BarTextField: View {
    let fieldID: BarTextFieldID
    let prompt: String
    @Binding var text: String
    @Binding var activeField: BarTextFieldID?
    var icon: String? = nil
    var shape: BarTextFieldShape = .rounded
    var showsClearButton = false
    var clearTextOnEscape = false
    var onSubmit: (() -> Void)? = nil
    
    private let cornerRadius: CGFloat = 7
    private let fieldHeight: CGFloat = 28
    
    private var showsFocusBorder: Bool {
        activeField == fieldID
    }
    
    private var borderColor: Color {
        showsFocusBorder ? Color.accentColor : Color(nsColor: .separatorColor)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .onSubmit { onSubmit?() }
                .background(
                    BarTextFieldFocusObserver(
                        fieldID: fieldID,
                        text: $text,
                        activeField: $activeField,
                        clearTextOnEscape: clearTextOnEscape
                    )
                )
            
            if showsClearButton, !text.isEmpty {
                Button {
                    text = ""
                    activeField = fieldID
                    if let window = NSApp.keyWindow {
                        BarTextFieldFocusRegistry.focus(fieldID, in: window)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .instantHoverTooltip(L10n.Pathbar.clear)
            }
        }
        .padding(.horizontal, shape == .capsule ? 10 : 8)
        .frame(height: fieldHeight)
        .background {
            Group {
                switch shape {
                case .rounded:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                case .capsule:
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
            }
            .allowsHitTesting(false)
        }
        .overlay {
            Group {
                switch shape {
                case .rounded:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                case .capsule:
                    Capsule(style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Path Bar

/// 地址栏路径输入框：进入编辑时在 becomeFirstResponder / textDidBeginEditing 中可靠全选。
final class PathBarTextField: NSTextField {
    var selectAllOnFocus = false
    var onCommit: (() -> Void)?
    var onTextChange: ((String) -> Void)?
    var onEditingBegan: (() -> Void)?
    var onEditingEnded: (() -> Void)?
    var onHistoryNavigate: ((PathBarHistoryDirection) -> String?)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure() {
        isEditable = true
        isSelectable = true
        isBordered = false
        isBezeled = false
        drawsBackground = false
        focusRingType = .none
        backgroundColor = .clear
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingMiddle
        cell?.wraps = false
        cell?.isScrollable = true
        font = .systemFont(ofSize: NSFont.systemFontSize)
        delegate = self
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard alphaValue > 0.01 else { return nil }
        return super.hitTest(point)
    }
    
    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused {
            onEditingBegan?()
            applySelectAllIfNeeded()
        }
        return focused
    }
    
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onEditingEnded?()
        }
        return resigned
    }
    
    func prepareSelectAllOnFocus() {
        selectAllOnFocus = true
    }
    
    func selectAllText() {
        guard window != nil else { return }
        if currentEditor() == nil {
            if window?.firstResponder !== self {
                window?.makeFirstResponder(self)
            }
            selectText(nil)
        }
        if let editor = currentEditor() {
            window?.makeFirstResponder(editor)
            editor.selectAll(nil)
        }
    }
    
    private func applySelectAllIfNeeded() {
        guard selectAllOnFocus else { return }
        selectAllText()
        selectAllOnFocus = false
    }
}

extension PathBarTextField: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        applySelectAllIfNeeded()
    }
    
    func controlTextDidChange(_ obj: Notification) {
        onTextChange?(stringValue)
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        onEditingEnded?()
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            onCommit?()
            return true
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            return applyHistoryNavigation(.up)
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            return applyHistoryNavigation(.down)
        }
        return false
    }

    @discardableResult
    private func applyHistoryNavigation(_ direction: PathBarHistoryDirection) -> Bool {
        guard let onHistoryNavigate, let value = onHistoryNavigate(direction) else { return false }
        stringValue = value
        onTextChange?(value)
        if let editor = currentEditor() {
            window?.makeFirstResponder(editor)
            let length = (value as NSString).length
            editor.selectedRange = NSRange(location: length, length: 0)
        }
        return true
    }
}

struct PathBarTextFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var activeField: BarTextFieldID?
    var isVisible: Bool
    var retainHighlight: Bool
    var onSubmit: () -> Void
    var onHistoryNavigate: ((PathBarHistoryDirection) -> String?)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, activeField: $activeField)
    }
    
    func makeNSView(context: Context) -> PathBarTextField {
        let field = PathBarTextField()
        field.stringValue = text
        field.onCommit = { [weak coordinator = context.coordinator] in
            coordinator?.onSubmit()
        }
        field.onTextChange = { [weak coordinator = context.coordinator] newValue in
            coordinator?.text.wrappedValue = newValue
        }
        field.onEditingBegan = { [weak coordinator = context.coordinator] in
            coordinator?.activeField.wrappedValue = .path
        }
        field.onEditingEnded = { [weak coordinator = context.coordinator] in
            coordinator?.handleEditingEnded()
        }
        field.onHistoryNavigate = onHistoryNavigate
        context.coordinator.field = field
        return field
    }
    
    func updateNSView(_ nsView: PathBarTextField, context: Context) {
        BarTextFieldFocusRegistry.register(nsView, for: .path)
        context.coordinator.text = $text
        context.coordinator.activeField = $activeField
        context.coordinator.onSubmit = onSubmit
        context.coordinator.retainHighlight = retainHighlight
        nsView.onHistoryNavigate = onHistoryNavigate
        
        let wasVisible = context.coordinator.wasVisible
        context.coordinator.wasVisible = isVisible
        
        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        nsView.alphaValue = isVisible ? 1 : 0
        nsView.isEnabled = true
        
        guard isVisible else { return }
        guard let window = nsView.window else { return }
        
        let shouldSelectAll = BarTextFieldFocusRegistry.hasPendingSelectAll(.path, in: window)
            || (!wasVisible && isVisible)
        guard shouldSelectAll else { return }
        
        nsView.prepareSelectAllOnFocus()
        nsView.selectAllText()
        BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
        DispatchQueue.main.async {
            nsView.prepareSelectAllOnFocus()
            nsView.window?.makeFirstResponder(nsView)
            nsView.selectAllText()
            if let window = nsView.window {
                BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
            }
        }
    }
    
    final class Coordinator {
        var text: Binding<String>
        var activeField: Binding<BarTextFieldID?>
        var onSubmit: () -> Void = {}
        var retainHighlight = false
        var wasVisible = false
        weak var field: PathBarTextField?
        
        init(text: Binding<String>, activeField: Binding<BarTextFieldID?>) {
            self.text = text
            self.activeField = activeField
        }
        
        func handleEditingEnded() {
            guard !retainHighlight else { return }
            guard activeField.wrappedValue == .path else { return }
            if let window = field?.window {
                activeField.wrappedValue = BarTextFieldFocusRegistry.currentEditingField(in: window)
            } else {
                activeField.wrappedValue = nil
            }
        }
    }
}

private enum PathBarMode {
    case breadcrumb
    case text
}

private struct PathSegment: Identifiable, Equatable {
    let id: Int
    let name: String
    let path: String
}

private enum PathSegmentBuilder {
    static func showsLeadingRootSlash(for path: String) -> Bool {
        guard !TrashLoader.isTrashPath(path) else { return false }
        return (path as NSString).standardizingPath.hasPrefix("/")
    }
    
    static func segments(for path: String) -> [PathSegment] {
        if TrashLoader.isTrashPath(path) {
            return [PathSegment(id: 0, name: TrashLoader.displayName, path: path)]
        }
        
        let standardized = (path as NSString).standardizingPath
        if standardized == "/" {
            return []
        }
        
        let components = standardized.split(separator: "/").map(String.init)
        guard !components.isEmpty else {
            return [PathSegment(id: 0, name: standardized, path: standardized)]
        }
        
        var segments: [PathSegment] = []
        var built = ""
        
        for component in components {
            built = built.isEmpty
                ? "/\(component)"
                : (built as NSString).appendingPathComponent(component)
            segments.append(
                PathSegment(id: segments.count, name: component, path: built)
            )
        }
        
        return segments
    }
}

private struct PathSubdirectory: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
}

private enum PathSubdirectoryCache {
    private struct Entry {
        let subdirectories: [PathSubdirectory]
        let timestamp: Date
    }
    
    private static var storage: [String: Entry] = [:]
    private static var accessOrder: [String] = []
    private static let lock = NSLock()
    private static let ttl: TimeInterval = 60
    private static let maxEntries = 50
    
    static func invalidate() {
        lock.lock()
        storage.removeAll()
        accessOrder.removeAll()
        lock.unlock()
    }
    
    static func preloadBreadcrumbPaths(_ path: String, showHiddenFiles: Bool) {
        guard !DirectorySizeVolumeFilter.isNetworkVolume(path: path) else { return }
        var parentPaths = PathSegmentBuilder.segments(for: path).dropLast().map(\.path)
        if PathSegmentBuilder.showsLeadingRootSlash(for: path), path != "/" {
            if parentPaths.first != "/" {
                parentPaths.insert("/", at: 0)
            }
        }
        guard !parentPaths.isEmpty else { return }
        let pathsToPreload = parentPaths

        Task.detached(priority: .utility) {
            for parentPath in pathsToPreload {
                _ = load(parentPath: parentPath, showHiddenFiles: showHiddenFiles)
            }
        }
    }
    
    static func load(
        parentPath: String,
        showHiddenFiles: Bool
    ) -> [PathSubdirectory] {
        let key = cacheKey(parentPath: parentPath, showHiddenFiles: showHiddenFiles)
        
        lock.lock()
        if let entry = storage[key], Date().timeIntervalSince(entry.timestamp) < ttl {
            touchLocked(key)
            let cached = entry.subdirectories
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let subdirectories = enumerateSubdirectories(
            parentPath: parentPath,
            showHiddenFiles: showHiddenFiles
        )
        
        lock.lock()
        storage[key] = Entry(subdirectories: subdirectories, timestamp: Date())
        touchLocked(key)
        evictIfNeededLocked()
        lock.unlock()
        return subdirectories
    }
    
    private static func touchLocked(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    private static func evictIfNeededLocked() {
        while storage.count > maxEntries, let oldest = accessOrder.first {
            accessOrder.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
    
    private static func cacheKey(parentPath: String, showHiddenFiles: Bool) -> String {
        "\(parentPath)|\(showHiddenFiles)"
    }
    
    private static func enumerateSubdirectories(
        parentPath: String,
        showHiddenFiles: Bool
    ) -> [PathSubdirectory] {
        let parentURL = URL(fileURLWithPath: parentPath, isDirectory: true)
        let propertyKeys: [URLResourceKey] = [.isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]
        
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: propertyKeys,
            options: options
        ) else {
            return []
        }
        
        var subdirectories: [PathSubdirectory] = []
        subdirectories.reserveCapacity(urls.count)
        for url in urls {
            guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDirectory else { continue }
            let resolvedPath = url.standardizedFileURL.path
            subdirectories.append(
                PathSubdirectory(id: resolvedPath, name: url.lastPathComponent, path: resolvedPath)
            )
        }
        
        return subdirectories.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

struct PathBarView: View {
    @Binding var path: String
    @Binding var activeField: BarTextFieldID?
    @Binding var isTextMode: Bool
    var hostWindow: NSWindow?
    var showHiddenFiles: Bool
    var historyEntries: [String] = []
    var onSelectHistory: ((String) -> Void)?
    /// 回车或点击跳转：目录进入对应路径；文件则进入父目录并选中该文件。
    var onCommitNavigation: (ExternalNavigationTarget) -> Void
    
    @State private var mode: PathBarMode = .breadcrumb
    @State private var editingText = ""
    @State private var committedViaSubmit = false
    @State private var previousActiveField: BarTextFieldID?
    @State private var historyBrowsing = PathBarHistoryBrowsing()
    
    private let cornerRadius: CGFloat = 7
    private let fieldHeight: CGFloat = 28
    private let pathBarTrailingClickWidth: CGFloat = 40
    private let pathBarHistoryButtonWidth: CGFloat = 24
    
    private var showsFocusBorder: Bool {
        mode == .text || activeField == .path
    }
    
    private var borderColor: Color {
        showsFocusBorder ? Color.accentColor : Color(nsColor: .separatorColor)
    }
    
    private var displayPath: String {
        path
    }

    private var showsHistoryMenu: Bool {
        !historyEntries.isEmpty && onSelectHistory != nil
    }

    private var pathBarContentTrailingInset: CGFloat {
        var inset: CGFloat = 0
        if mode == .text {
            inset += pathBarTrailingClickWidth
        }
        if showsHistoryMenu {
            inset += pathBarHistoryButtonWidth
        }
        if pendingNavigationTarget != nil {
            inset += 24
        }
        return inset
    }

    private var pendingNavigationTarget: ExternalNavigationTarget? {
        guard mode == .text else { return nil }
        let raw = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        guard let resolved = ExternalFolderOpenRequestResolver.resolve(fromPathText: raw) else {
            return nil
        }

        let current = (path as NSString).standardizingPath
        let directory = (resolved.directoryPath as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        if let selectionPath = resolved.selectionPath {
            let fileExists = FileManager.default.fileExists(atPath: selectionPath)
            let parentExists = FileManager.default.fileExists(
                atPath: directory,
                isDirectory: &isDirectory
            ) && isDirectory.boolValue
            guard fileExists || parentExists else { return nil }
            return ExternalNavigationTarget(
                directoryPath: resolved.directoryPath,
                selectionPath: selectionPath
            )
        }

        guard directory != current else { return nil }
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return ExternalNavigationTarget(
            directoryPath: resolved.directoryPath,
            selectionPath: nil
        )
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            PathBarTextFieldRepresentable(
                text: $editingText,
                activeField: $activeField,
                isVisible: mode == .text,
                retainHighlight: mode == .text,
                onSubmit: commitPath,
                onHistoryNavigate: browsePathHistory
            )
            .allowsHitTesting(mode == .text)
            .padding(.trailing, pathBarContentTrailingInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            
            if mode == .breadcrumb {
                PathBreadcrumbView(
                    path: path,
                    showHiddenFiles: showHiddenFiles,
                    onNavigate: { path = $0 },
                    onRequestEdit: enterTextMode
                )
                .padding(.trailing, showsHistoryMenu ? pathBarHistoryButtonWidth : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: fieldHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .trailing) {
            if mode == .text {
                PathBarBlankClickArea(onClick: handlePathBarTrailingClick)
                    .frame(width: pathBarTrailingClickWidth, height: fieldHeight)
                    .instantHoverTooltip(L10n.Pathbar.selectAll)
            }
        }
        .overlay(alignment: .trailing) {
            if let target = pendingNavigationTarget {
                PathBarNavigateButton(targetPath: target.selectionPath ?? target.directoryPath) { _ in
                    navigateToPendingTarget(target)
                }
                .frame(width: 24, height: fieldHeight)
                .padding(.trailing, showsHistoryMenu ? pathBarHistoryButtonWidth + 2 : 2)
            }
        }
        .overlay(alignment: .trailing) {
            if showsHistoryMenu {
                PathBarHistoryMenuButton(
                    entries: historyEntries,
                    currentPath: path,
                    onSelect: { onSelectHistory?($0) }
                )
                .frame(width: pathBarHistoryButtonWidth, height: fieldHeight)
                .padding(.trailing, 2)
            }
        }
        .background(PathBarRootRegistrar())
        .onAppear {
            editingText = displayPath
            previousActiveField = activeField
            isTextMode = mode == .text
            PathSubdirectoryCache.preloadBreadcrumbPaths(path, showHiddenFiles: showHiddenFiles)
        }
        .onChange(of: path) { _ in
            historyBrowsing.reset()
            if mode == .breadcrumb || activeField != .path {
                editingText = displayPath
            }
            PathSubdirectoryCache.preloadBreadcrumbPaths(path, showHiddenFiles: showHiddenFiles)
        }
        .onChange(of: showHiddenFiles) { _ in
            PathSubdirectoryCache.invalidate()
            PathSubdirectoryCache.preloadBreadcrumbPaths(path, showHiddenFiles: showHiddenFiles)
        }
        .onReceive(NotificationCenter.default.publisher(for: .meoFindMemoryPressure)) { _ in
            PathSubdirectoryCache.invalidate()
        }
        .onChange(of: mode) { newMode in
            isTextMode = newMode == .text
            guard newMode == .text else { return }
            activeField = .path
            requestPathFieldFocus()
        }
        .onChange(of: isTextMode) { active in
            guard !active, mode == .text else { return }
            if let window = resolvedHostWindow {
                BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
            }
            editingText = displayPath
            committedViaSubmit = false
            mode = .breadcrumb
            if let window = resolvedHostWindow {
                BarTextFieldFocusRegistry.endEditing(.path, in: window)
            }
            if activeField == .path {
                if let window = resolvedHostWindow {
                    activeField = BarTextFieldFocusRegistry.currentEditingField(in: window)
                } else {
                    activeField = nil
                }
            }
        }
        .onChange(of: activeField) { newValue in
            let oldValue = previousActiveField
            previousActiveField = newValue
            
            if newValue == .path {
                if mode != .text {
                    editingText = displayPath
                    mode = .text
                }
                return
            }
            
            if oldValue == .path, mode == .text, newValue != .path {
                if !committedViaSubmit {
                    editingText = displayPath
                }
                committedViaSubmit = false
                mode = .breadcrumb
                isTextMode = false
                if let window = resolvedHostWindow {
                    BarTextFieldFocusRegistry.endEditing(.path, in: window)
                }
            }
        }
    }
    
    private var resolvedHostWindow: NSWindow? {
        hostWindow ?? NSApp.keyWindow
    }
    
    private func requestPathFieldFocus() {
        guard let window = resolvedHostWindow else { return }
        BarTextFieldFocusRegistry.focusAndSelectAll(.path, in: window)
        activeField = .path
    }
    
    private func enterTextMode() {
        guard let window = resolvedHostWindow else { return }
        BarTextFieldFocusRegistry.requestSelectAll(.path, in: window)
        editingText = displayPath
        activeField = .path
        isTextMode = true
        if mode == .text {
            BarTextFieldFocusRegistry.focusAndSelectAll(.path, in: window)
        } else {
            mode = .text
        }
    }
    
    private func handlePathBarTrailingClick() {
        guard let window = resolvedHostWindow else { return }
        if mode == .text {
            BarTextFieldFocusRegistry.focusAndSelectAll(.path, in: window)
        } else {
            enterTextMode()
        }
    }
    
    private func commitPath() {
        committedViaSubmit = true
        historyBrowsing.reset()
        if let window = resolvedHostWindow {
            BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
        }
        let newValue = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newValue.isEmpty,
           let resolved = ExternalFolderOpenRequestResolver.resolve(fromPathText: newValue) {
            editingText = resolved.directoryPath
            onCommitNavigation(
                ExternalNavigationTarget(
                    directoryPath: resolved.directoryPath,
                    selectionPath: resolved.selectionPath
                )
            )
        }
        if let window = resolvedHostWindow {
            BarTextFieldFocusRegistry.endEditing(.path, in: window)
            activeField = BarTextFieldFocusRegistry.currentEditingField(in: window)
        } else {
            activeField = nil
        }
        mode = .breadcrumb
    }

    private func navigateToPendingTarget(_ target: ExternalNavigationTarget) {
        committedViaSubmit = true
        historyBrowsing.reset()
        if let window = resolvedHostWindow {
            BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
        }
        editingText = target.directoryPath
        onCommitNavigation(target)
        isTextMode = false
        if let window = resolvedHostWindow {
            BarTextFieldFocusRegistry.endEditing(.path, in: window)
            activeField = BarTextFieldFocusRegistry.currentEditingField(in: window)
        } else {
            activeField = nil
        }
        mode = .breadcrumb
    }

    private func browsePathHistory(_ direction: PathBarHistoryDirection) -> String? {
        historyBrowsing.step(direction, currentDraft: editingText, entries: historyEntries)
    }
}

private struct PathBarHistoryMenuButton: View {
    let entries: [String]
    let currentPath: String
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(entries, id: \.self) { entry in
                let isCurrent = (entry as NSString).standardizingPath
                    == (currentPath as NSString).standardizingPath
                Button {
                    onSelect(entry)
                } label: {
                    if isCurrent {
                        Label(displayName(for: entry), systemImage: "checkmark")
                    } else {
                        Text(displayName(for: entry))
                    }
                }
            }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .instantHoverTooltip(L10n.Pathbar.history)
    }

    private func displayName(for path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if standardized == home {
            return "~"
        }
        if standardized.hasPrefix(home + "/") {
            return "~" + String(standardized.dropFirst(home.count))
        }
        return standardized
    }
}

private struct PathBarRootRegistrar: NSViewRepresentable {
    func makeNSView(context: Context) -> RegistrarView {
        RegistrarView()
    }
    
    func updateNSView(_ nsView: RegistrarView, context: Context) {
        nsView.registerIfNeeded()
    }
    
    final class RegistrarView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            registerIfNeeded()
        }
        
        override func layout() {
            super.layout()
            registerIfNeeded()
        }
        
        fileprivate func registerIfNeeded() {
            guard bounds.width > 0, bounds.height >= 24, bounds.height <= 52 else { return }
            BarTextFieldFocusRegistry.registerPathBarRoot(self)
        }
        
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

private struct PathBarNavigateButton: NSViewRepresentable {
    let targetPath: String
    let onNavigate: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigate: onNavigate)
    }
    
    func makeNSView(context: Context) -> NavigateButton {
        let button = NavigateButton(
            image: NSImage(systemSymbolName: "arrow.right.circle.fill", accessibilityDescription: L10n.Pathbar.commit) ?? NSImage(),
            target: context.coordinator,
            action: #selector(Coordinator.navigate(_:))
        )
        button.isBordered = false
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.contentTintColor = .controlAccentColor
        button.setButtonType(.momentaryChange)
        context.coordinator.targetPath = targetPath
        return button
    }
    
    func updateNSView(_ nsView: NavigateButton, context: Context) {
        context.coordinator.targetPath = targetPath
        context.coordinator.onNavigate = onNavigate
        nsView.registerWithFocusRegistry()
    }
    
    final class NavigateButton: NSButton {
        private var tooltipTrackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tooltipTrackingArea {
                removeTrackingArea(tooltipTrackingArea)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            tooltipTrackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            guard event.trackingArea === tooltipTrackingArea else { return }
            RailTooltipPresenter.show(text: L10n.Pathbar.commit, anchor: self)
        }

        override func mouseExited(with event: NSEvent) {
            guard event.trackingArea === tooltipTrackingArea else { return }
            RailTooltipPresenter.hide()
        }

        deinit {
            RailTooltipPresenter.hide()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            registerWithFocusRegistry()
        }
        
        override func layout() {
            super.layout()
            registerWithFocusRegistry()
        }
        
        fileprivate func registerWithFocusRegistry() {
            BarTextFieldFocusRegistry.registerPathNavigateButton(self)
        }
    }
    
    final class Coordinator: NSObject {
        var targetPath: String
        var onNavigate: (String) -> Void
        
        init(targetPath: String = "", onNavigate: @escaping (String) -> Void) {
            self.targetPath = targetPath
            self.onNavigate = onNavigate
        }
        
        @objc func navigate(_ sender: NSButton) {
            onNavigate(targetPath)
        }
    }
}

private struct PathBarBlankClickArea: NSViewRepresentable {
    let onClick: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onClick: onClick)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = ClickView()
        view.coordinator = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClick = onClick
        (nsView as? ClickView)?.coordinator = context.coordinator
    }
    
    final class Coordinator {
        var onClick: () -> Void
        
        init(onClick: @escaping () -> Void) {
            self.onClick = onClick
        }
    }
    
    final class ClickView: NSView {
        weak var coordinator: Coordinator?
        
        override var isFlipped: Bool { true }
        
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard bounds.width > 0, bounds.height > 0, bounds.contains(point) else { return nil }
            return self
        }
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            registerIfNeeded()
        }
        
        override func layout() {
            super.layout()
            registerIfNeeded()
        }
        
        private func registerIfNeeded() {
            guard bounds.width > 0, bounds.height > 0 else { return }
            BarTextFieldFocusRegistry.registerPathBarBlankClickArea(self)
        }
        
        override func mouseDown(with event: NSEvent) {
            if let window {
                BarTextFieldFocusRegistry.requestSelectAll(.path, in: window)
            }
            coordinator?.onClick()
        }
        
        override var acceptsFirstResponder: Bool { false }
    }
}

private struct BreadcrumbTrailingEdgeKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct BreadcrumbTrailingClickArea: View {
    let height: CGFloat
    let onRequestEdit: () -> Void
    
    var body: some View {
        PathBarBlankClickArea(onClick: onRequestEdit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
            .instantHoverTooltip(L10n.Pathbar.edit)
    }
}

private struct PathBreadcrumbView: View {
    let path: String
    let showHiddenFiles: Bool
    let onNavigate: (String) -> Void
    let onRequestEdit: () -> Void
    
    @State private var hoveredSegmentID: Int?
    @State private var contentTrailingEdge: CGFloat = 0
    
    private let fieldHeight: CGFloat = 28
    
    private var segments: [PathSegment] {
        PathSegmentBuilder.segments(for: path)
    }
    
    private var showsLeadingRootSlash: Bool {
        PathSegmentBuilder.showsLeadingRootSlash(for: path)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let layout = PathBreadcrumbLayout.compute(
                segments: segments,
                availableWidth: geometry.size.width,
                showsLeadingRootSlash: showsLeadingRootSlash
            )
            let barWidth = geometry.size.width
            let estimatedWidth = layout.estimatedDisplayWidth(
                allSegments: segments,
                showsLeadingRootSlash: showsLeadingRootSlash
            )
            let fitsInBar = contentTrailingEdge > 0
                ? contentTrailingEdge < barWidth
                : estimatedWidth < barWidth
            
            Group {
                if fitsInBar {
                    HStack(spacing: 0) {
                        breadcrumbContent(layout: layout)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        BreadcrumbTrailingClickArea(
                            height: fieldHeight,
                            onRequestEdit: onRequestEdit
                        )
                        .layoutPriority(-1)
                    }
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            breadcrumbContent(layout: layout)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(width: barWidth, height: fieldHeight, alignment: .leading)
                        .onChange(of: path) { _ in
                            contentTrailingEdge = 0
                            if let lastID = segments.last?.id {
                                scrollProxy.scrollTo(lastID, anchor: .trailing)
                            }
                        }
                        .onAppear {
                            if let lastID = segments.last?.id {
                                scrollProxy.scrollTo(lastID, anchor: .trailing)
                            }
                        }
                    }
                }
            }
            .coordinateSpace(name: "pathBreadcrumb")
            .frame(width: barWidth, height: fieldHeight, alignment: .leading)
            .onPreferenceChange(BreadcrumbTrailingEdgeKey.self) { edge in
                guard edge > 0, abs(edge - contentTrailingEdge) > 0.5 else { return }
                contentTrailingEdge = edge
            }
            .onChange(of: path) { _ in
                contentTrailingEdge = 0
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: fieldHeight)
        .onHover { hovering in
            if !hovering {
                hoveredSegmentID = nil
            }
        }
    }
    
    @ViewBuilder
    private func breadcrumbContent(layout: PathBreadcrumbLayout) -> some View {
        HStack(alignment: .center, spacing: 0) {
            if showsLeadingRootSlash {
                PathRootSlashButton(
                    onNavigate: { onNavigate("/") }
                )
            }
            
            if let leadingSegment = layout.fixedLeadingSegment {
                PathSegmentButton(
                    segment: leadingSegment,
                    isHighlighted: isSegmentHighlighted(leadingSegment),
                    onNavigate: onNavigate
                )
                .id(leadingSegment.id)
                .onHover { hovering in
                    if hovering {
                        hoveredSegmentID = leadingSegment.id
                    }
                }
                
                if layout.showsLeadingEllipsis || !layout.visibleSegments.isEmpty {
                    PathSeparatorMenu(
                        parentPath: leadingSegment.path,
                        showHiddenFiles: showHiddenFiles,
                        onNavigate: onNavigate
                    )
                }
            }
            
            if layout.showsLeadingEllipsis {
                PathBreadcrumbEllipsisMenu(
                    hiddenSegments: layout.hiddenSegments,
                    onNavigate: onNavigate
                )
                
                if layout.visibleSegments.first != nil,
                   let separatorParent = layout.hiddenSegments.last?.path {
                    PathSeparatorMenu(
                        parentPath: separatorParent,
                        showHiddenFiles: showHiddenFiles,
                        onNavigate: onNavigate
                    )
                }
            }
            
            ForEach(layout.visibleSegments) { segment in
                let isLast = segment.id == segments.last?.id
                
                PathSegmentButton(
                    segment: segment,
                    isHighlighted: isSegmentHighlighted(segment),
                    onNavigate: onNavigate
                )
                .id(segment.id)
                .onHover { hovering in
                    if hovering {
                        hoveredSegmentID = segment.id
                    }
                }
                
                if !isLast {
                    PathSeparatorMenu(
                        parentPath: segment.path,
                        showHiddenFiles: showHiddenFiles,
                        onNavigate: onNavigate
                    )
                }
            }
            
            breadcrumbTrailingMarker()
        }
        .frame(height: fieldHeight)
    }
    
    @ViewBuilder
    private func breadcrumbTrailingMarker() -> some View {
        Color.clear
            .frame(width: 0, height: fieldHeight)
            .background {
                GeometryReader { contentGeometry in
                    Color.clear
                        .preference(
                            key: BreadcrumbTrailingEdgeKey.self,
                            value: contentGeometry.frame(in: .named("pathBreadcrumb")).maxX
                        )
                }
            }
    }
    
    private func isSegmentHighlighted(_ segment: PathSegment) -> Bool {
        guard let hoveredSegmentID else { return false }
        return segment.id <= hoveredSegmentID
    }
}

private struct PathBreadcrumbLayout {
    let showsLeadingEllipsis: Bool
    let fixedLeadingSegment: PathSegment?
    let hiddenSegments: [PathSegment]
    let visibleSegments: [PathSegment]
    
    func estimatedDisplayWidth(
        allSegments: [PathSegment],
        showsLeadingRootSlash: Bool
    ) -> CGFloat {
        guard fixedLeadingSegment != nil else {
            return Self.estimatedBreadcrumbWidth(
                for: allSegments,
                showsLeadingRootSlash: showsLeadingRootSlash
            )
        }
        
        let segmentWidths = allSegments.map(Self.estimatedWidth(for:))
        let tailStart = hiddenSegments.count + 1
        return Self.estimatedTruncatedWidth(
            segmentWidths: segmentWidths,
            tailStart: tailStart,
            tailCount: visibleSegments.count,
            showsLeadingRootSlash: showsLeadingRootSlash,
            showsEllipsis: showsLeadingEllipsis,
            ellipsisWidth: Self.ellipsisWidth
        )
    }
    
    static func compute(
        segments: [PathSegment],
        availableWidth: CGFloat,
        showsLeadingRootSlash: Bool
    ) -> PathBreadcrumbLayout {
        guard !segments.isEmpty || showsLeadingRootSlash else {
            return PathBreadcrumbLayout(
                showsLeadingEllipsis: false,
                fixedLeadingSegment: nil,
                hiddenSegments: [],
                visibleSegments: []
            )
        }
        
        let usableWidth = max(0, availableWidth)
        let ellipsisWidth = Self.ellipsisWidth
        let segmentWidths = segments.map(estimatedWidth(for:))
        let totalWidth = estimatedBreadcrumbWidth(
            for: segments,
            showsLeadingRootSlash: showsLeadingRootSlash
        )
        
        if totalWidth <= usableWidth {
            return PathBreadcrumbLayout(
                showsLeadingEllipsis: false,
                fixedLeadingSegment: nil,
                hiddenSegments: [],
                visibleSegments: segments
            )
        }
        
        guard let firstSegment = segments.first else {
            return PathBreadcrumbLayout(
                showsLeadingEllipsis: false,
                fixedLeadingSegment: nil,
                hiddenSegments: [],
                visibleSegments: []
            )
        }
        
        var tailStart = max(1, segments.count - 1)
        if segments.count > 1 {
            for candidate in 1..<segments.count {
                let showsEllipsis = candidate > 1
                let width = estimatedTruncatedWidth(
                    segmentWidths: segmentWidths,
                    tailStart: candidate,
                    tailCount: segments.count - candidate,
                    showsLeadingRootSlash: showsLeadingRootSlash,
                    showsEllipsis: showsEllipsis,
                    ellipsisWidth: ellipsisWidth
                )
                if width <= usableWidth {
                    tailStart = candidate
                    break
                }
            }
        }
        
        let hidden = tailStart > 1 ? Array(segments[1..<tailStart]) : []
        let visible = tailStart < segments.count ? Array(segments[tailStart...]) : []
        return PathBreadcrumbLayout(
            showsLeadingEllipsis: !hidden.isEmpty,
            fixedLeadingSegment: firstSegment,
            hiddenSegments: hidden,
            visibleSegments: visible
        )
    }
    
    private static func estimatedTruncatedWidth(
        segmentWidths: [CGFloat],
        tailStart: Int,
        tailCount: Int,
        showsLeadingRootSlash: Bool,
        showsEllipsis: Bool,
        ellipsisWidth: CGFloat
    ) -> CGFloat {
        let rootPrefixWidth = showsLeadingRootSlash ? estimatedRootSlashWidth() : 0
        guard !segmentWidths.isEmpty else { return rootPrefixWidth }
        
        var width = rootPrefixWidth + segmentWidths[0]
        guard tailCount > 0 || showsEllipsis else { return width }
        
        width += separatorWidth
        
        if showsEllipsis {
            width += ellipsisWidth + separatorWidth
        }
        
        guard tailCount > 0 else { return width }
        
        let tailWidths = segmentWidths[tailStart...]
        width += tailWidths.reduce(0, +)
        width += separatorWidth * CGFloat(max(0, tailCount - 1))
        return width
    }
    
    static let separatorWidth: CGFloat = 14
    static let ellipsisWidth: CGFloat = 20
    
    static func estimatedBreadcrumbWidth(
        for segments: [PathSegment],
        showsLeadingRootSlash: Bool
    ) -> CGFloat {
        var width: CGFloat = 0
        if showsLeadingRootSlash {
            width += estimatedRootSlashWidth()
        }
        guard !segments.isEmpty else { return width }
        let segmentWidths = segments.map(estimatedWidth(for:))
        let separators = separatorWidth * CGFloat(max(0, segments.count - 1))
        return width + segmentWidths.reduce(0, +) + separators
    }
    
    private static func estimatedRootSlashWidth() -> CGFloat {
        separatorWidth
    }
    
    private static func estimatedWidth(for segment: PathSegment) -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let textWidth = ceil((segment.name as NSString).size(withAttributes: [.font: font]).width)
        return textWidth + 8
    }
}

private struct PathRootSlashButton: View {
    let onNavigate: () -> Void
    
    var body: some View {
        Text("/")
            .font(.system(size: NSFont.systemFontSize))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 2)
            .frame(width: 14, height: 28)
            .contentShape(Rectangle())
            .onTapGesture(perform: onNavigate)
            .instantHoverTooltip("/")
    }
}

private struct PathSegmentButton: View {
    let segment: PathSegment
    let isHighlighted: Bool
    let onNavigate: (String) -> Void
    
    var body: some View {
        Button {
            onNavigate(segment.path)
        } label: {
            Text(segment.name)
                .font(.system(size: NSFont.systemFontSize))
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .frame(height: 28)
        .instantHoverTooltip(segment.path)
    }
}

private struct PathSeparatorMenu: View {
    let parentPath: String
    let showHiddenFiles: Bool
    let onNavigate: (String) -> Void
    
    var body: some View {
        Menu {
            PathSeparatorMenuItems(
                parentPath: parentPath,
                showHiddenFiles: showHiddenFiles,
                onNavigate: onNavigate
            )
        } label: {
            Text("/")
                .font(.system(size: NSFont.systemFontSize))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
                .frame(width: 14, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .instantHoverTooltip(L10n.Pathbar.subdirs)
    }
}

private struct PathSeparatorMenuItems: View {
    let parentPath: String
    let showHiddenFiles: Bool
    let onNavigate: (String) -> Void
    
    private var subdirectories: [PathSubdirectory] {
        PathSubdirectoryCache.load(
            parentPath: parentPath,
            showHiddenFiles: showHiddenFiles
        )
    }
    
    var body: some View {
        if subdirectories.isEmpty {
            Text(L10n.Pathbar.noSubdirs)
                .disabled(true)
        } else {
            ForEach(subdirectories) { subdirectory in
                Button(subdirectory.name) {
                    onNavigate(subdirectory.path)
                }
            }
        }
    }
}

private struct PathBreadcrumbEllipsisMenu: View {
    let hiddenSegments: [PathSegment]
    let onNavigate: (String) -> Void
    
    var body: some View {
        Menu {
            ForEach(hiddenSegments) { segment in
                Button(segment.name) {
                    onNavigate(segment.path)
                }
            }
        } label: {
            Text("…")
                .font(.system(size: NSFont.systemFontSize, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .instantHoverTooltip(L10n.Pathbar.parent)
    }
}
