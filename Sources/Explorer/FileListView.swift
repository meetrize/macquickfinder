import SwiftUI
import AppKit
import FileList

struct FileListView: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    @Binding var showPreview: Bool
    let searchText: String
    let isContentSearchActive: Bool
    @Binding var quickSearchText: String
    @Binding var isQuickSearchVisible: Bool
    @Binding var isFileListRenaming: Bool
    let focusToken: UInt
    let currentDirectoryPath: String
    let canNavigateToParent: Bool
    let showHiddenFiles: Bool
    let directoryMetadataOverlay: DirectoryMetadataOverlay
    let viewMode: FileListViewMode
    let thumbnailLayoutMode: FileListThumbnailLayoutMode
    let panoramaExpandDepthPolicy: PanoramaExpandDepthPolicy
    let thumbnailCellSize: CGFloat
    let useIconPreview: Bool
    let preferWorkspaceIconsInThumbnail: Bool
    let isLoading: Bool
    let onThumbnailCellSizeChange: (CGFloat) -> Void
    let onItemOpen: (FileItem, Bool) -> Void
    let onBlankDoubleClick: () -> Void
    let onItemsChanged: ([String]) -> Void
    let onScheduleVisibleDirectorySizes: ([String]) -> Void
    let onScheduleVisibleDirectoryItemCounts: ([String]) -> Void
    let contextActions: FileContextActions
    let blankMenuActions: FileListBlankMenuActions
    let canNavigateBack: Bool
    let onNavigateBack: () -> Void
    let onNavigateToDirectory: (String) -> Void
    
    @ObservedObject private var preferencesStore = FileListPreferencesStore.shared
    @StateObject private var panoramaController = PanoramaTreeController()
    @State private var isCurrentDirectoryDropTargeted = false
    @State private var isQuickSearchFieldFocused = false
    @State private var quickSearchAutoCloseWorkItem: DispatchWorkItem?
    @State private var isQuickSearchTabKeyDown = false
    @AppStorage("explorer.treeExpandEnabled") private var treeExpandEnabled = true
    @AppStorage(AppPreferences.FileList.rowHoverHighlight) private var rowHoverHighlight = true
    @State private var expandedDirectoryIDs: Set<String> = []
    @State private var expandingDirectoryIDs: Set<String> = []
    @State private var cachedChildrenByDirectoryID: [String: [FileItem]] = [:]
    @State private var expandErrorByDirectoryID: [String: String] = [:]
    @State private var directoryLoadGenerationByID: [String: UInt] = [:]
    
    private var showParentDirectoryRow: Bool {
        canNavigateToParent && searchText.isEmpty
    }
    
    private struct VisibleNode {
        let item: FileItem
        let depth: Int
        let parentID: String?
    }
    
    private var rootItemsByID: [String: FileItem] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }
    
    private var treeEnabled: Bool {
        viewMode == .list && treeExpandEnabled && searchText.isEmpty
    }

    private var effectiveThumbnailLayoutMode: FileListThumbnailLayoutMode {
        guard viewMode == .thumbnail, searchText.isEmpty, !isLoading else { return .grid }
        return thumbnailLayoutMode
    }

    private var panoramaActive: Bool {
        effectiveThumbnailLayoutMode == .panorama
    }
    
    private var visibleTreeNodes: [VisibleNode] {
        guard treeEnabled else {
            return items.map { VisibleNode(item: $0, depth: 0, parentID: nil) }
        }
        var nodes: [VisibleNode] = []
        nodes.reserveCapacity(items.count)
        appendVisibleNodes(
            from: items,
            depth: 0,
            parentID: nil,
            result: &nodes
        )
        return nodes
    }
    
    private var tableRowItems: [FileItem] {
        var rows: [FileItem] = []
        if showParentDirectoryRow {
            rows.append(FileItem.parentDirectoryEntry())
        }
        rows.append(contentsOf: visibleTreeNodes.map(\.item))
        return rows
    }
    
    private var parentDirectoryURL: URL? {
        FileItem.parentDirectoryURL(from: currentDirectoryPath)
    }
    
    var body: some View {
        FileListPanelLayout {
            Group {
                if isLoading && items.isEmpty {
                    FileListLoadingPlaceholderView(
                        viewMode: viewMode,
                        thumbnailCellSize: thumbnailCellSize
                    )
                } else {
                    ZStack(alignment: .top) {
                        switch viewMode {
                        case .list:
                            fileTable
                        case .thumbnail:
                            if panoramaActive {
                                panoramaTree
                            } else {
                                fileThumbnailGrid
                            }
                        }
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(FileListAutoFocusRequester(token: focusToken, isRenaming: isFileListRenaming))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isCurrentDirectoryDropTargeted {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if isQuickSearchVisible {
                quickSearchBar
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .onChange(of: isQuickSearchVisible) { visible in
            if !visible {
                cancelQuickSearchAutoClose()
                isQuickSearchFieldFocused = false
                return
            }
            refreshQuickSearchAutoCloseTimer()
        }
        .onChange(of: isQuickSearchFieldFocused) { _ in
            refreshQuickSearchAutoCloseTimer()
        }
        .onDisappear {
            cancelQuickSearchAutoClose()
            PanoramaTreeControllerBridge.bind(nil)
            panoramaController.shutdown()
        }
        .onChange(of: currentDirectoryPath) { _ in
            closeQuickSearch()
            isFileListRenaming = false
            FileListTableController.shared?.cancelRenameIfNeededForDataUpdate()
            resetTreeState(keepExpanded: false)
            syncPanoramaLifecycle(forceReset: true)
        }
        .onChange(of: showHiddenFiles) { _ in
            resetTreeState(keepExpanded: true)
            syncPanoramaLifecycle(forceReset: true)
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                expandingDirectoryIDs.removeAll()
            }
            syncPanoramaLifecycle(forceReset: false)
        }
        .onChange(of: items) { _ in
            syncPanoramaRootItemsIfNeeded()
        }
        .onChange(of: thumbnailLayoutMode) { _ in
            syncPanoramaLifecycle(forceReset: true)
        }
        .onChange(of: panoramaExpandDepthPolicy) { _ in
            syncPanoramaLifecycle(forceReset: true)
        }
        .onChange(of: viewMode) { _ in
            syncPanoramaLifecycle(forceReset: true)
        }
        .onChange(of: isLoading) { _ in
            syncPanoramaLifecycle(forceReset: false)
        }
        .onChange(of: preferencesStore.preferences.sort) { _ in
            syncPanoramaLifecycle(forceReset: true)
        }
        .onAppear {
            syncPanoramaLifecycle(forceReset: true)
        }
    }
    
    private var fileTable: some View {
        let listRows = makeListRows()
        let tableInteraction = makeFileListInteraction()

        return FileListTableHost(
            rows: listRows,
            interaction: tableInteraction,
            selection: Binding(
                get: { selection },
                set: { selection = $0 }
            ),
            preferencesStore: preferencesStore,
            onOpenRow: { intent in
                guard let item = tableRowItems.first(where: { $0.id == intent.row.id }) else { return }
                onItemOpen(item, intent.openInDetachedPreview)
            },
            onVisibleDirectoryPathsChanged: onScheduleVisibleDirectorySizes,
            directorySizeProvider: nil,
            useIconPreview: useIconPreview,
            rowHoverHighlight: rowHoverHighlight
        )
        .onAppear {
            preferencesStore.resetToDefaultIfNeeded()
            DirectoryMetadataAppKitBridge.shared.installIfNeeded(overlay: directoryMetadataOverlay)
        }
    }

    private var fileThumbnailGrid: some View {
        let listRows = makeListRows()
        let tableInteraction = makeFileListInteraction()

        return FileListThumbnailHost(
            rows: listRows,
            interaction: tableInteraction,
            selection: Binding(
                get: { selection },
                set: { selection = $0 }
            ),
            preferencesStore: preferencesStore,
            cellSize: thumbnailCellSize,
            onCellSizeChange: onThumbnailCellSizeChange,
            onOpenRow: { intent in
                guard let item = tableRowItems.first(where: { $0.id == intent.row.id }) else { return }
                onItemOpen(item, intent.openInDetachedPreview)
            },
            onVisibleDirectoryPathsChanged: { paths in
                onScheduleVisibleDirectorySizes(paths)
                onScheduleVisibleDirectoryItemCounts(paths)
            },
            directorySizeProvider: nil,
            directoryItemCountProvider: nil,
            preferWorkspaceIcons: preferWorkspaceIconsInThumbnail,
            rowHoverHighlight: rowHoverHighlight
        )
        .onAppear {
            preferencesStore.resetToDefaultIfNeeded()
            DirectoryMetadataAppKitBridge.shared.installIfNeeded(overlay: directoryMetadataOverlay)
        }
    }

    private var panoramaTree: some View {
        PanoramaTreeView(
            controller: panoramaController,
            cellSize: thumbnailCellSize,
            selection: $selection,
            rowHoverHighlight: rowHoverHighlight,
            rootItems: items,
            onThumbnailCellSizeChange: onThumbnailCellSizeChange,
            onItemOpen: onItemOpen,
            onNavigateToDirectory: onNavigateToDirectory
        )
        .onAppear {
            preferencesStore.resetToDefaultIfNeeded()
            DirectoryMetadataAppKitBridge.shared.installIfNeeded(overlay: directoryMetadataOverlay)
            syncPanoramaLifecycle(forceReset: true)
        }
    }

    private func syncPanoramaLifecycle(forceReset: Bool) {
        if panoramaActive {
            PanoramaTreeControllerBridge.bind(panoramaController)
        } else {
            PanoramaTreeControllerBridge.bind(nil)
            panoramaController.shutdown()
            return
        }
        guard !isLoading else { return }

        let sort = preferencesStore.preferences.sort
        if forceReset || panoramaController.dataSource.rootDirectoryPath != currentDirectoryPath {
            panoramaController.reset(
                rootPath: currentDirectoryPath,
                rootItems: items,
                showHiddenFiles: showHiddenFiles,
                sort: sort,
                depthPolicy: panoramaExpandDepthPolicy
            )
        } else {
            syncPanoramaRootItemsIfNeeded()
        }
    }

    private func syncPanoramaRootItemsIfNeeded() {
        guard panoramaActive, !isLoading else { return }
        panoramaController.applyRootItems(items)
    }
    
    private func makeFileListInteraction() -> FileListTableInteraction {
        FileListTableInteraction(
            searchText: searchText,
            quickSearchText: quickSearchText,
            isContentSearchActive: isContentSearchActive,
            blankMenuActions: blankMenuActions,
            onBlankSingleClick: {
                if !selection.isEmpty {
                    selection.removeAll()
                }
            },
            onBlankDoubleClick: onBlankDoubleClick,
            canDelete: {
                !selection.isEmpty && !selection.contains(FileItem.parentDirectoryID)
            },
            onDelete: {
                let deletable = items(for: selection).filter { !$0.isParentDirectoryEntry }
                contextActions.delete(deletable)
            },
            canNavigateBack: { canNavigateBack },
            onNavigateBack: onNavigateBack,
            onTableFocusChanged: { focused in
                guard focused, isQuickSearchVisible else { return }
                // AppKit 表格接管 firstResponder 时，显式让快速搜索框失焦并启动自动关闭计时。
                isQuickSearchFieldFocused = false
                refreshQuickSearchAutoCloseTimer()
            },
            onQuickSearchInput: { input in
                appendQuickSearchText(input)
            },
            onQuickSearchBackspace: {
                removeLastQuickSearchCharacter()
            },
            onQuickSearchEscape: {
                closeQuickSearch()
            },
            onQuickSearchCycleMatch: { forward in
                cycleQuickSearchMatch(forward: forward)
            },
            onQuickSearchTabKeyDown: {
                noteQuickSearchTabKeyDown()
            },
            onQuickSearchTabKeyUp: {
                noteQuickSearchTabKeyUp()
            },
            onDragEnded: {
                resetTreeState(keepExpanded: true)
                onItemsChanged([])
            },
            onToggleExpand: { row in
                guard row.isDirectory, !row.isParentDirectoryEntry else { return }
                toggleExpansion(for: row.id)
            },
            canRename: { row in
                !row.isParentDirectoryEntry && !contextActions.isInTrash
            },
            performRename: { row, newName, completion in
                guard let item = tableRowItems.first(where: { $0.id == row.id }) else {
                    completion(false)
                    return
                }
                let oldPath = item.id
                switch FileOperations.moveItem(item, toNewName: newName) {
                case .success(let newURL):
                    selection = [newURL.path]
                    resetTreeState(keepExpanded: true)
                    onItemsChanged([oldPath])
                    completion(true)
                case .failure(let error):
                    NSAlert(error: error as NSError).runModal()
                    completion(false)
                }
            },
            onRenameEditingChanged: { isFileListRenaming = $0 },
            makeContextMenu: { clickedRow, selectedIDs in
                let selectedItems = tableRowItems.filter { selectedIDs.contains($0.id) }
                return FileListRowContextMenuBuilder.makeMenu(
                    clickedRow: clickedRow,
                    selectedItems: selectedItems,
                    currentDirectoryPath: currentDirectoryPath,
                    showHiddenFiles: showHiddenFiles,
                    actions: contextActions
                )
            },
            popUpContextMenu: { menu, event, view, fileURLs in
                FileServicesMenuSupport.popUpContextMenu(menu, with: event, for: view, fileURLs: fileURLs)
            },
            servicesRequestor: FileServicesMenuRequestor.shared,
            dropDestinationPath: { row in
                if row.isParentDirectoryEntry {
                    return parentDirectoryURL?.path
                }
                guard row.isDirectory else { return nil }
                return row.iconPath
            },
            currentDirectoryDropPath: currentDirectoryPath,
            canAcceptDrop: { destinationPath, urls in
                let destination = URL(fileURLWithPath: destinationPath, isDirectory: true)
                return FileOperations.canMoveItems(urls, to: destination)
            },
            performDrop: { destinationPath, urls, copy in
                let destination = URL(fileURLWithPath: destinationPath, isDirectory: true)
                FileOperations.moveItems(urls, to: destination, copy: copy) {
                    resetTreeState(keepExpanded: true)
                    onItemsChanged(invalidationPaths(for: urls, destinationPath: destinationPath))
                }
            },
            onCurrentDirectoryDropHighlightChanged: { isTargeted in
                isCurrentDirectoryDropTargeted = isTargeted
            },
            onSpacePreview: {
                guard !selection.isEmpty else { return }
                showPreview = true
            },
            onQuickSearchMatchSelected: { _ in
                showPreview = true
            }
        )
    }
    
    private func items(for ids: Set<FileItem.ID>) -> [FileItem] {
        tableRowItems.filter { ids.contains($0.id) }
    }
    
    private func makeListRows() -> [FileListRow] {
        var rows: [FileListRow] = []
        rows.reserveCapacity(tableRowItems.count)
        
        if showParentDirectoryRow {
            rows.append(FileListRow(item: FileItem.parentDirectoryEntry()))
        }
        
        for node in visibleTreeNodes {
            let item = node.item
            rows.append(
                FileListRow(
                    item: item,
                    directorySizeDisplay: nil,
                    depth: node.depth,
                    parentID: node.parentID,
                    isExpandable: item.isDirectory && !item.isParentDirectoryEntry,
                    isExpanded: expandedDirectoryIDs.contains(item.id),
                    isExpanding: expandingDirectoryIDs.contains(item.id),
                    expandErrorMessage: expandErrorByDirectoryID[item.id]
                )
            )
        }
        return rows
    }
    
    private func appendVisibleNodes(
        from sourceItems: [FileItem],
        depth: Int,
        parentID: String?,
        result: inout [VisibleNode]
    ) {
        for item in sourceItems {
            result.append(VisibleNode(item: item, depth: depth, parentID: parentID))
            guard treeEnabled,
                  item.isDirectory,
                  expandedDirectoryIDs.contains(item.id),
                  let children = cachedChildrenByDirectoryID[item.id]
            else { continue }
            appendVisibleNodes(
                from: children,
                depth: depth + 1,
                parentID: item.id,
                result: &result
            )
        }
    }
    
    private func toggleExpansion(for directoryID: String) {
        guard treeEnabled else { return }
        if expandedDirectoryIDs.contains(directoryID) {
            collapse(directoryID)
            return
        }
        expandedDirectoryIDs.insert(directoryID)
        expandErrorByDirectoryID[directoryID] = nil
        if cachedChildrenByDirectoryID[directoryID] == nil {
            loadChildren(for: directoryID)
        }
    }
    
    private func collapse(_ directoryID: String) {
        expandedDirectoryIDs.remove(directoryID)
        expandingDirectoryIDs.remove(directoryID)
        expandErrorByDirectoryID[directoryID] = nil
        
        let descendantPrefix = directoryID.hasSuffix("/") ? directoryID : directoryID + "/"
        expandedDirectoryIDs = expandedDirectoryIDs.filter { !$0.hasPrefix(descendantPrefix) }
        expandingDirectoryIDs = expandingDirectoryIDs.filter { !$0.hasPrefix(descendantPrefix) }
    }
    
    private func loadChildren(for directoryID: String) {
        let currentGeneration = (directoryLoadGenerationByID[directoryID] ?? 0) + 1
        directoryLoadGenerationByID[directoryID] = currentGeneration
        expandingDirectoryIDs.insert(directoryID)
        
        let shouldShowHiddenFiles = showHiddenFiles
        let parentCanonical = URL(fileURLWithPath: currentDirectoryPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        let listingOptions = DirectoryListingOptions.forPath(directoryID)
        
        Task.detached(priority: .userInitiated) {
            do {
                let canonicalPath = URL(fileURLWithPath: directoryID).resolvingSymlinksInPath().standardizedFileURL.path
                if canonicalPath == parentCanonical {
                    throw NSError(
                        domain: "Explorer.FileTree",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: L10n.Error.symlinkLoop]
                    )
                }
                
                let loaded = try DirectoryListingLoader.loadFileItems(
                    at: directoryID,
                    showHiddenFiles: shouldShowHiddenFiles,
                    options: listingOptions
                )
                
                await MainActor.run {
                    guard directoryLoadGenerationByID[directoryID] == currentGeneration else { return }
                    cachedChildrenByDirectoryID[directoryID] = loaded
                    expandingDirectoryIDs.remove(directoryID)
                    expandErrorByDirectoryID[directoryID] = nil
                }
            } catch {
                await MainActor.run {
                    guard directoryLoadGenerationByID[directoryID] == currentGeneration else { return }
                    cachedChildrenByDirectoryID[directoryID] = []
                    expandingDirectoryIDs.remove(directoryID)
                    let nsError = error as NSError
                    if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
                        expandErrorByDirectoryID[directoryID] = L10n.Error.noPermission
                    } else if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
                        expandErrorByDirectoryID[directoryID] = L10n.Error.directoryNotFound
                    } else {
                        expandErrorByDirectoryID[directoryID] = nsError.localizedDescription
                    }
                }
            }
        }
    }
    
    private func resetTreeState(keepExpanded: Bool) {
        expandingDirectoryIDs.removeAll()
        expandErrorByDirectoryID.removeAll()
        directoryLoadGenerationByID.removeAll()
        if keepExpanded {
            cachedChildrenByDirectoryID.removeAll()
        } else {
            cachedChildrenByDirectoryID.removeAll()
            expandedDirectoryIDs.removeAll()
        }
    }

    private var quickSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            QuickSearchTextField(
                placeholder: L10n.Search.quickSearch,
                text: $quickSearchText,
                isFocused: $isQuickSearchFieldFocused,
                onTabKeyDown: {
                    noteQuickSearchTabKeyDown()
                },
                onTabKeyUp: {
                    noteQuickSearchTabKeyUp()
                },
                onTab: { reverse in
                    guard isQuickSearchVisible, !quickSearchText.isEmpty else { return }
                    cycleQuickSearchMatch(forward: !reverse)
                }
            )
                .onChange(of: quickSearchText) { newValue in
                    let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if normalized != newValue {
                        quickSearchText = normalized
                        return
                    }
                    isQuickSearchVisible = !normalized.isEmpty
                    if normalized.isEmpty {
                        cancelQuickSearchAutoClose()
                    } else {
                        refreshQuickSearchAutoCloseTimer()
                    }
                }
            Button {
                closeQuickSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .instantHoverTooltip(L10n.Search.closeQuickSearch)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private func appendQuickSearchText(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        quickSearchText += trimmed
        isQuickSearchVisible = !quickSearchText.isEmpty
        refreshQuickSearchAutoCloseTimer()
    }

    private func removeLastQuickSearchCharacter() {
        guard !quickSearchText.isEmpty else { return }
        quickSearchText.removeLast()
        isQuickSearchVisible = !quickSearchText.isEmpty
        refreshQuickSearchAutoCloseTimer()
    }

    private func closeQuickSearch() {
        cancelQuickSearchAutoClose()
        isQuickSearchTabKeyDown = false
        quickSearchText = ""
        isQuickSearchVisible = false
    }

    private func cycleQuickSearchMatch(forward: Bool) {
        switch viewMode {
        case .list:
            FileListTableController.shared?.cycleQuickSearchMatch(forward: forward)
        case .thumbnail:
            FileListThumbnailController.shared?.cycleQuickSearchMatch(forward: forward)
        }
    }

    private func noteQuickSearchTabKeyDown() {
        isQuickSearchTabKeyDown = true
        cancelQuickSearchAutoClose()
    }

    private func noteQuickSearchTabKeyUp() {
        isQuickSearchTabKeyDown = false
        refreshQuickSearchAutoCloseTimer()
    }
    
    private func refreshQuickSearchAutoCloseTimer() {
        guard isQuickSearchVisible else {
            cancelQuickSearchAutoClose()
            return
        }
        // 快速搜索框聚焦或 Tab 跳转进行中时不自动关闭；松键且无输入后再计时。
        if isQuickSearchFieldFocused || isQuickSearchTabKeyDown {
            cancelQuickSearchAutoClose()
            return
        }
        
        cancelQuickSearchAutoClose()
        let workItem = DispatchWorkItem {
            closeQuickSearch()
        }
        quickSearchAutoCloseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }
    
    private func cancelQuickSearchAutoClose() {
        quickSearchAutoCloseWorkItem?.cancel()
        quickSearchAutoCloseWorkItem = nil
    }
    
    private func invalidationPaths(for urls: [URL], destinationPath: String) -> [String] {
        var paths = Set<String>()
        paths.insert(destinationPath)
        for url in urls {
            paths.insert(url.path)
        }
        return Array(paths)
    }
}
private struct QuickSearchTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    let onTabKeyDown: () -> Void
    let onTabKeyUp: () -> Void
    let onTab: (_ reverse: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> QuickSearchNSTextField {
        let field = QuickSearchNSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.placeholderString = placeholder
        field.lineBreakMode = .byTruncatingTail
        field.cell?.truncatesLastVisibleLine = true
        field.delegate = context.coordinator
        field.onFocusChanged = { focused in
            context.coordinator.isFocused = focused
        }
        field.onTabKeyUp = {
            context.coordinator.onTabKeyUp()
        }
        return field
    }

    func updateNSView(_ nsView: QuickSearchNSTextField, context: Context) {
        context.coordinator.onTextChange = { text = $0 }
        context.coordinator.onTabKeyDown = onTabKeyDown
        context.coordinator.onTabKeyUp = onTabKeyUp
        context.coordinator.onTab = onTab
        context.coordinator.isFocusedBinding = $isFocused
        nsView.onTabKeyUp = onTabKeyUp
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
        if isFocused, nsView.window?.firstResponder !== nsView.currentEditor() {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var onTextChange: (String) -> Void = { _ in }
        var onTabKeyDown: () -> Void = {}
        var onTabKeyUp: () -> Void = {}
        var onTab: (_ reverse: Bool) -> Void = { _ in }
        var isFocusedBinding: Binding<Bool>?
        var isFocused = false {
            didSet {
                guard isFocused != oldValue else { return }
                isFocusedBinding?.wrappedValue = isFocused
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            onTextChange(field.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                onTabKeyDown()
                onTab(false)
                return true
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                onTabKeyDown()
                onTab(true)
                return true
            }
            return false
        }
    }
}

private final class QuickSearchNSTextField: NSTextField {
    var onFocusChanged: ((Bool) -> Void)?
    var onTabKeyUp: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocusChanged?(true) }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChanged?(false) }
        return resigned
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 48 {
            onTabKeyUp?()
        }
        super.keyUp(with: event)
    }
}

private struct FileListAutoFocusRequester: NSViewRepresentable {
    let token: UInt
    let isRenaming: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.syncRenamingState(isRenaming)
        context.coordinator.requestFocusIfNeeded(token: token, view: nsView)
    }
    
    final class Coordinator {
        private var lastToken: UInt = 0
        private var isRenaming = false

        func syncRenamingState(_ isRenaming: Bool) {
            self.isRenaming = isRenaming
        }
        
        func requestFocusIfNeeded(token: UInt, view: NSView) {
            guard token != lastToken else { return }
            lastToken = token
            
            // 左侧点击切目录时，NSTableView 可能尚未完成挂载或 firstResponder 仍被侧栏占用；
            // 这里做几次轻量重试（短延迟），不阻塞也不影响目录大小计算。
            scheduleFocusAttempt(token: token, view: view, delay: 0)
            scheduleFocusAttempt(token: token, view: view, delay: 0.03)
            scheduleFocusAttempt(token: token, view: view, delay: 0.12)
        }
        
        private func scheduleFocusAttempt(token: UInt, view: NSView, delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak view] in
                guard let self, let view else { return }
                guard token == self.lastToken else { return }
                guard !self.isRenaming else { return }
                guard !OutputPanelTextEditingCenter.shared.isActive else { return }
                guard let window = view.window,
                      let contentView = window.contentView,
                      let tableView = Self.findFileListTableView(in: contentView)
                else { return }
                
                if window.firstResponder === tableView {
                    return
                }
                if Self.isTextEditingResponder(window.firstResponder) {
                    return
                }
                window.makeFirstResponder(tableView)
            }
        }

        private static func isTextEditingResponder(_ responder: NSResponder?) -> Bool {
            guard let responder else { return false }
            if responder is NSTextView { return true }
            if let field = responder as? NSTextField, field.isEditable { return true }
            return false
        }
        
        private static func findFileListTableView(in root: NSView) -> NSTableView? {
            if let table = root as? NSTableView, table.delegate is FileListTableController {
                return table
            }
            for subview in root.subviews {
                if let found = findFileListTableView(in: subview) {
                    return found
                }
            }
            return nil
        }
    }
}
