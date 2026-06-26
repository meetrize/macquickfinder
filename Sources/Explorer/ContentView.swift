import SwiftUI
import AppKit
import FileList

extension ExternalNavigationTarget {
    init(request: ExternalFolderOpenCenter.OpenRequest) {
        self.init(
            directoryPath: request.directoryPath,
            selectionPath: request.selectionPath
        )
    }
}

extension ContentView {
    func applyExternalNavigationTarget(_ target: ExternalNavigationTarget) {
        pendingExternalSelectionPath = target.selectionPath
        if path == target.directoryPath {
            loadItems()
        } else {
            path = target.directoryPath
        }
    }

    func applyPendingExternalSelectionIfNeeded(loadedItems: [FileItem], for directoryPath: String) {
        guard directoryPath == path else { return }
        guard let pendingExternalSelectionPath else { return }
        defer { self.pendingExternalSelectionPath = nil }
        guard loadedItems.contains(where: { $0.id == pendingExternalSelectionPath }) else { return }
        selection = [pendingExternalSelectionPath]
    }
}
struct ContentView: View {
    private let initialPath: String?

    @Environment(\.openWindow) private var openWindow
    @StateObject private var layout = ExplorerWindowLayoutState()
    @AppStorage("blankDoubleClickAction")
    private var blankDoubleClickActionRaw = BlankDoubleClickAction.navigateToParent.rawValue
    @State private var path: String
    @State private var items: [FileItem] = []
    @State private var selection: Set<FileItem.ID> = []
    @State private var sortOrder: SortOrder = .nameAscending
    @ObservedObject private var fileListPreferences = FileListPreferencesStore.shared
    private let directoryMetadataOverlay = DirectoryMetadataOverlay.shared
    @State private var isSyncingSortFromPreferences = false
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var quickSearchText = ""
    @State private var isQuickSearchVisible = false
    @State private var fileListFocusToken: UInt = 0
    @State private var showHiddenFiles = false
    @State private var loadGeneration: UInt = 0
    @State private var pathNavigation = PathNavigationHistory()
    @State private var isApplyingHistoryNavigation = false
    @State private var lastRecordedPath: String?
    @AppStorage(AppPreferences.Directory.autoCalculateDirectorySizes) private var autoCalculateDirectorySizes = true
    @AppStorage(AppPreferences.Directory.useIconPreview) private var useIconPreview = false
    @State private var livePreviewPanelWidth: CGFloat = 320
    @State private var activeBarField: BarTextFieldID?
    @State private var previewHostWindowID = UUID()
    @State private var hostWindow: NSWindow?
    @State private var isFileListRenaming = false
    @State private var isPathBarTextMode = false
    @State private var liveLeftPanelDragWidth: CGFloat?
    @StateObject private var externalFolderOpenCenter = ExternalFolderOpenCenter.shared
    @ObservedObject private var outputPanelTextEditing = OutputPanelTextEditingCenter.shared
    @ObservedObject private var toolbarStore = ToolbarCustomizationStore.shared
    @ObservedObject private var connectServerCenter = ConnectServerCenter.shared
    @State private var pendingExternalSelectionPath: String?
    @State private var showConnectServerSheet = false
    @State private var transientNoticeMessage: String?
    
    init(initialPath: String? = nil) {
        self.initialPath = initialPath
        _path = State(initialValue: initialPath ?? FileManager.default.homeDirectoryForCurrentUser.path)
    }
    
    private let leftPanelConstants = LeftPanelLayoutConstants()
    
    private var isTextFieldEditing: Bool {
        activeBarField != nil || isFileListRenaming
    }

    private var isAnyTextFieldEditing: Bool {
        isTextFieldEditing || outputPanelTextEditing.isActive
    }
    
    private var fileListViewMode: FileListViewMode {
        layout.fileListViewMode
    }

    private var thumbnailCellSize: CGFloat {
        layout.thumbnailCellSizeValue
    }

    private var currentDirectoryTitle: String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "MeoFind" }
        let url = URL(fileURLWithPath: trimmed)
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }
    
    private var fileListTableItems: [FileItem] {
        let showParent = FileItem.canNavigateUp(from: path) && searchText.isEmpty
        if showParent {
            return [FileItem.parentDirectoryEntry()] + filteredItems
        }
        return filteredItems
    }
    
    private let minPreviewPanelWidth: CGFloat = 200
    private let minMainPanelWidth: CGFloat = 360
    
    private var leftPanelMode: LeftPanelMode { layout.leftPanelMode }
    
    private var leftPanelLastVisibleMode: LeftPanelVisibleMode { layout.leftPanelLastVisibleMode }
    
    private var leftPanelSidebarWidth: CGFloat { layout.leftPanelSidebarWidthValue }
    
    private var leftPanelVisibleWidth: CGFloat {
        layout.leftPanelVisibleWidth
    }
    
    /// 拖拽过程中面板宽度跟随鼠标；松手后回退到 `leftPanelVisibleWidth`。
    private var leftPanelDisplayWidth: CGFloat {
        if let live = liveLeftPanelDragWidth {
            switch leftPanelMode {
            case .sidebar:
                return leftPanelConstants.clampedSidebarWidth(live)
            case .rail:
                return leftPanelConstants.railDisplayWidth(liveDragWidth: live)
            case .hidden:
                return 0
            }
        }
        return leftPanelVisibleWidth
    }
    
    private func handleLeftPanelDrag(delta: CGFloat) {
        let baseWidth = liveLeftPanelDragWidth ?? leftPanelDisplayWidth
        let proposed = baseWidth + delta
        liveLeftPanelDragWidth = proposed
        layout.applyLeftPanelDrag(proposedWidth: proposed, baseWidth: baseWidth)
        if layout.leftPanelMode == .hidden {
            // 拖入隐藏后 divider 会被移出视图，mouseUp 可能到不了；清掉 live 宽度避免再次显示时用脏值。
            liveLeftPanelDragWidth = nil
        }
    }
    
    private func handleLeftPanelDragEnded() {
        liveLeftPanelDragWidth = nil
    }
    
    private func toggleLeftPanelVisibility() {
        liveLeftPanelDragWidth = nil
        layout.toggleLeftPanelVisibility()
    }
    
    private func restoredLaunchPath() -> String {
        ExplorerWindowLayoutState.restoredLastOpenedPath()
    }
    
    var body: some View {
        GeometryReader { outer in
            let containerHeight = outer.size.height
            let outputMaxHeight = OutputPanelMetrics.maxPanelHeight(forContainerHeight: containerHeight)
            ZStack(alignment: .bottom) {
                GeometryReader { geometry in
                let maxPreviewWidth = max(
                    minPreviewPanelWidth,
                    geometry.size.width - minMainPanelWidth
                )
                
                HStack(spacing: 0) {
                    if leftPanelMode != .hidden {
                        Group {
                            Group {
                                switch leftPanelMode {
                                case .sidebar:
                                    SidebarView(
                                        path: $path,
                                        onItemsChanged: {
                                            selection.removeAll()
                                            loadItems()
                                        },
                                        onReload: {
                                            selection.removeAll()
                                            loadItems()
                                        }
                                    )
                                case .rail:
                                    SidebarRailView(
                                        path: $path,
                                        onItemsChanged: {
                                            selection.removeAll()
                                            loadItems()
                                        },
                                        onReload: {
                                            selection.removeAll()
                                            loadItems()
                                        }
                                    )
                                case .hidden:
                                    EmptyView()
                                }
                            }
                            .frame(width: leftPanelDisplayWidth)
                            .frame(maxHeight: .infinity)
                            
                            LeadingResizeDivider(
                                onResize: handleLeftPanelDrag(delta:),
                                onDragEnded: handleLeftPanelDragEnded
                            )
                            .frame(width: 6)
                            .frame(maxHeight: .infinity)
                        }
                        .animation(nil, value: liveLeftPanelDragWidth)
                    }
                    
                    HStack(spacing: 0) {
                        explorerBrowserColumn
                        
                        if layout.showPreview || layout.showSnippets {
                            explorerRightPanelColumn(maxPreviewWidth: maxPreviewWidth)
                        }
                    }
                    .animation(nil, value: livePreviewPanelWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        livePreviewPanelWidth = clampPreviewWidth(
                            CGFloat(layout.previewPanelWidth),
                            maxWidth: maxPreviewWidth
                        )
                    }
                    .onChange(of: geometry.size.width) { newWidth in
                        let maxPreview = max(minPreviewPanelWidth, newWidth - minMainPanelWidth)
                        let clamped = clampPreviewWidth(livePreviewPanelWidth, maxWidth: maxPreview)
                        if clamped != livePreviewPanelWidth {
                            livePreviewPanelWidth = clamped
                            layout.previewPanelWidth = Double(clamped)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            OutputPanelView(
                layout: layout,
                containerHeight: containerHeight,
                maxPanelHeight: outputMaxHeight,
                hostWindow: hostWindow,
                executionContext: OutputExecutionContext(
                    cwd: path,
                    selectedItems: FileItem.resolveSelection(ids: selection, from: items),
                    showHiddenFiles: showHiddenFiles
                ),
                onNavigateToDirectory: { newPath in
                    selection.removeAll()
                    path = newPath
                }
            )
            .zIndex(1)
            }
            .frame(width: outer.size.width, height: outer.size.height)
            .focusedValue(\.textFieldEditing, isAnyTextFieldEditing)
            .background(TextEditingKeyMonitor(isActive: isAnyTextFieldEditing))
        }
        .background(WindowKeyLayoutTracker(layout: layout).frame(width: 0, height: 0).accessibilityHidden(true))
        .background(HostWindowReader(window: $hostWindow).frame(width: 0, height: 0).accessibilityHidden(true))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closingWindow = notification.object as? NSWindow,
                  closingWindow == hostWindow else { return }
            PreviewDetachCoordinator.shared.onHostWindowWillClose(hostWindowID: previewHostWindowID)
        }
        .settingsWindowOpenBridge()
        .background(
            BarFieldOutsideClickHandler(
                activeField: $activeBarField,
                isPathBarTextMode: $isPathBarTextMode,
                tableItems: fileListTableItems
            )
        )
        .onAppear {
            toolbarStore.loadIfNeeded()
            externalFolderOpenCenter.setOpenFolderWindowHandler { path in
                openWindow(id: ExplorerWindowScene.folder, value: path)
            }

            if let mapped = fileListPreferences.sort.explorerSortOrder {
                sortOrder = mapped
            }
            
            // 初始化时做一次自愈：持久化宽度可能越界。
            layout.healLeftPanelSidebarWidth()
            if let initialPath {
                path = initialPath
            } else if let launchRequest = externalFolderOpenCenter.consumePendingRequest() {
                pendingExternalSelectionPath = launchRequest.selectionPath
                path = launchRequest.directoryPath
            } else {
                path = restoredLaunchPath()
            }
            lastRecordedPath = path
            layout.recordLastOpenedPath(path)
            loadItems()
        }
        .onReceive(externalFolderOpenCenter.$targetRequest.compactMap { $0 }) { request in
            applyExternalNavigationTarget(ExternalNavigationTarget(request: request))
        }
        .onChange(of: connectServerCenter.presentSheetToken) { _ in
            guard hostWindow == NSApp.keyWindow else { return }
            showConnectServerSheet = true
        }
        .sheet(isPresented: $showConnectServerSheet) {
            ConnectServerSheet(
                initialAddress: RecentServersStore.shared.bookmarks.first?.urlString ?? ""
            ) { mountURL in
                NetworkVolumePrewarmer.touchPath(mountURL.path)
                path = mountURL.path
                ConnectServerCenter.shared.requestDevicesRefresh()
            }
        }
        .onChange(of: path) { newPath in
            let wasHistoryNavigation = isApplyingHistoryNavigation
            if let oldPath = lastRecordedPath, oldPath != newPath, !wasHistoryNavigation {
                var history = pathNavigation
                history.recordNavigation(from: oldPath, to: newPath)
                pathNavigation = history
            }
            lastRecordedPath = newPath
            if wasHistoryNavigation {
                isApplyingHistoryNavigation = false
            }
            layout.recordLastOpenedPath(newPath)
            loadItems()
        }
        .onChange(of: autoCalculateDirectorySizes) { enabled in
            handleAutoCalculateDirectorySizesChanged(enabled)
        }
        .onChange(of: sortOrder) { newOrder in
            guard !isSyncingSortFromPreferences else { return }
            fileListPreferences.updateSort(FileListSortState(sortOrder: newOrder))
        }
        .onChange(of: fileListPreferences.preferences.sort) { newSort in
            guard let mapped = newSort.explorerSortOrder else { return }
            guard mapped != sortOrder else { return }
            isSyncingSortFromPreferences = true
            sortOrder = mapped
            isSyncingSortFromPreferences = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didUnmountNotification)) { notification in
            guard let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else {
                return
            }
            handleVolumeUnmount(volumePath: volumeURL.path)
        }
        .onReceive(NotificationCenter.default.publisher(for: .explorerTransientNotice)) { notification in
            guard let message = notification.userInfo?["message"] as? String else { return }
            showTransientNotice(message)
        }
        .overlay(alignment: .bottom) {
            if let transientNoticeMessage {
                Text(transientNoticeMessage)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: transientNoticeMessage)
    }
    
    private var filteredItems: [FileItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    @ViewBuilder
    private var explorerBrowserColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                PathBarNavigationButtons(
                    canGoBack: canNavigateBack,
                    canGoForward: canNavigateForward,
                    onBack: navigateBack,
                    onForward: navigateForward
                )

                PathBarView(
                    path: $path,
                    activeField: $activeBarField,
                    isTextMode: $isPathBarTextMode,
                    hostWindow: hostWindow,
                    showHiddenFiles: showHiddenFiles,
                    historyEntries: pathNavigation.recentEntries(currentPath: path),
                    onSelectHistory: navigateToHistoryPath,
                    onSubmit: { loadItems() }
                )
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .padding(.leading, 0)
            .padding(.trailing, 8)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)
            
            Divider()
            
            explorerFileListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .focusedValue(
            \.windowLayoutCommands,
            WindowLayoutCommands(
                showPreview: layout.showPreview,
                showSnippets: layout.showSnippets,
                isOutputPanelVisible: layout.isOutputPanelVisible,
                toggleLeftPanel: { layout.toggleLeftPanelVisibility() },
                toggleRightPanel: { layout.toggleRightPanel() },
                togglePreview: { layout.showPreview.toggle() },
                toggleSnippets: { layout.showSnippets.toggle() },
                toggleOutputPanel: { layout.toggleOutputPanel() }
            )
        )
        .background(BarTextFieldFocusSync(activeField: $activeBarField))
        .navigationTitle(currentDirectoryTitle)
        .modifier(InlineToolbarTitleModifier())
        .toolbar {
            ExplorerDynamicToolbar(
                store: toolbarStore,
                environment: toolbarEnvironment,
                searchContent: {
                    BarTextField(
                        fieldID: .search,
                        prompt: L10n.Search.prompt,
                        text: $searchText,
                        activeField: $activeBarField,
                        icon: "magnifyingglass",
                        shape: .capsule,
                        showsClearButton: true
                    )
                    .frame(width: 220)
                }
            )
        }
        .background {
            ToolbarContextMenuInstaller(
                hostWindow: $hostWindow,
                isCustomizing: toolbarStore.isCustomizing,
                workingLayout: toolbarStore.workingLayout,
                onCustomize: {
                    ToolbarCustomizationWindowController.present(
                        store: toolbarStore,
                        environment: toolbarEnvironment,
                        parentWindow: hostWindow
                    )
                },
                onEditOpenApp: { action in
                    ToolbarOpenAppEditorWindowController.present(
                        store: toolbarStore,
                        parentWindow: hostWindow ?? ToolbarCustomizationWindowController.activeWindow,
                        editingAction: action
                    )
                },
                onDeleteOpenApp: { action in
                    toolbarStore.deleteCustomOpenApp(id: action.id)
                }
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .onChange(of: activeBarField) { field in
            guard let field, let hostWindow else { return }
            BarTextFieldFocusRegistry.focus(field, in: hostWindow)
        }
        .background {
            Button(L10n.Search.focus) {
                activeBarField = .search
            }
            .keyboardShortcut("f", modifiers: .command)
            .labelsHidden()
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            Button(L10n.Pathbar.back) {
                navigateBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .labelsHidden()
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .disabled(!canNavigateBack)

            Button(L10n.Pathbar.forward) {
                navigateForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .labelsHidden()
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .disabled(!canNavigateForward)
        }
    }

    private var toolbarEnvironment: ExplorerToolbarEnvironment {
        ExplorerToolbarEnvironment(
            layout: layout,
            showHiddenFiles: showHiddenFiles,
            sortOrder: sortOrder,
            autoCalculateDirectorySizes: autoCalculateDirectorySizes,
            useIconPreview: useIconPreview,
            fileListViewMode: fileListViewMode,
            selectedItems: selectedItems,
            deletableSelectedItems: deletableSelectedItems,
            leftPanelMode: leftPanelMode,
            isCustomizing: toolbarStore.isCustomizing,
            toggleLeftPanelVisibility: toggleLeftPanelVisibility,
            createNewFolder: createNewFolder,
            deleteSelectedItems: deleteSelectedItems,
            toggleHiddenFiles: {
                showHiddenFiles.toggle()
                loadItems()
            },
            setSortOrder: { sortOrder = $0 },
            toggleAutoCalculateDirectorySizes: { autoCalculateDirectorySizes.toggle() },
            toggleUseIconPreview: { useIconPreview.toggle() },
            performOpenApp: performToolbarOpenApp,
            editOpenApp: editToolbarOpenApp
        )
    }

    private func editToolbarOpenApp(_ action: CustomOpenAppAction) {
        ToolbarOpenAppEditorWindowController.present(
            store: toolbarStore,
            parentWindow: hostWindow,
            editingAction: action
        )
    }

    private func performToolbarOpenApp(_ action: CustomOpenAppAction) {
        let context = ToolbarActionContext(
            cwd: path,
            selectedItems: selectedItems
        )
        do {
            try OpenAppExecutor.run(action, context: context)
        } catch ToolbarActionError.applicationMissing(let name) {
            OpenAppExecutor.presentApplicationMissingAlert(name: name)
        } catch {
            return
        }
    }

    @ViewBuilder
    private func explorerRightPanelColumn(maxPreviewWidth: CGFloat) -> some View {
        HorizontalResizeDivider(
            trailingWidth: $livePreviewPanelWidth,
            minTrailingWidth: minPreviewPanelWidth,
            maxTrailingWidth: maxPreviewWidth,
            onDragEnded: {
                layout.previewPanelWidth = Double(livePreviewPanelWidth)
            }
        )
        .frame(width: 6)
        .frame(maxHeight: .infinity)
        
        RightPanelStackView(
            layout: layout,
            hostWindowID: previewHostWindowID,
            selection: selection,
            items: items,
            cwd: path,
            sortOrder: sortOrder,
            showHiddenFiles: showHiddenFiles,
            autoCalculateDirectorySizes: shouldAutoCalculateDirectorySizes(for: path),
            directoryMetadataOverlay: directoryMetadataOverlay,
            panelWidth: livePreviewPanelWidth,
            onNavigate: { path = $0 },
            onOpenItem: openItem,
            onOpenTerminalAtPath: { TerminalHelper.open(at: $0) }
        )
        .frame(width: livePreviewPanelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var explorerFileListSection: some View {
        let isNetworkVolume = DirectorySizeVolumeFilter.isNetworkVolume(path: path)
        return FileListView(
            items: filteredItems,
            selection: $selection,
            showPreview: $layout.showPreview,
            searchText: searchText,
            quickSearchText: $quickSearchText,
            isQuickSearchVisible: $isQuickSearchVisible,
            isFileListRenaming: $isFileListRenaming,
            focusToken: fileListFocusToken,
            currentDirectoryPath: path,
            canNavigateToParent: FileItem.canNavigateUp(from: path),
            showHiddenFiles: showHiddenFiles,
            directoryMetadataOverlay: directoryMetadataOverlay,
            viewMode: fileListViewMode,
            thumbnailCellSize: thumbnailCellSize,
            useIconPreview: useIconPreview && !isNetworkVolume,
            preferWorkspaceIconsInThumbnail: isNetworkVolume,
            isLoading: isLoading,
            onThumbnailCellSizeChange: { layout.thumbnailCellSizeValue = $0 },
            onItemOpen: openItem,
            onBlankDoubleClick: handleBlankDoubleClick,
            onItemsChanged: handleFileListItemsChanged,
            onScheduleVisibleDirectorySizes: scheduleVisibleDirectorySizes,
            onScheduleVisibleDirectoryItemCounts: scheduleVisibleDirectoryItemCounts,
            contextActions: fileContextActions,
            blankMenuActions: blankMenuActions,
            canNavigateBack: canNavigateBack,
            onNavigateBack: navigateBack
        )
        .focusedValue(\.fileCommandHandlers, fileCommandHandlers)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func clampPreviewWidth(_ width: CGFloat, maxWidth: CGFloat) -> CGFloat {
        min(max(width, minPreviewPanelWidth), max(maxWidth, minPreviewPanelWidth))
    }
    
    private func loadItems(invalidatingPaths: [String] = []) {
        loadGeneration += 1
        let currentGeneration = loadGeneration
        let currentPath = path
        let shouldShowHiddenFiles = showHiddenFiles
        let listingOptions = DirectoryListingOptions.forPath(currentPath)
        let isNetworkListing = listingOptions.lightweightMetadata

        // 立刻进入目标目录：清空旧列表并显示加载占位，不等待后台列举完成。
        isLoading = true
        items = []
        selection.removeAll()
        directoryMetadataOverlay.beginSession(generation: currentGeneration)

        if isNetworkListing {
            NetworkVolumePrewarmer.touchPath(currentPath)
        }
        
        Task {
            var didApplyItems = false
            defer {
                Task { @MainActor in
                    guard currentGeneration == loadGeneration, !didApplyItems else { return }
                    isLoading = false
                }
            }

            if isNetworkListing, !TrashLoader.isTrashPath(currentPath) {
                var loadedItems: [FileItem] = []
                do {
                    loadedItems = try await Task.detached(priority: .userInitiated) {
                        try DirectoryListingLoader.loadFileItems(
                            at: currentPath,
                            showHiddenFiles: shouldShowHiddenFiles,
                            options: listingOptions,
                            onEachURL: { _ in try Task.checkCancellation() }
                        )
                    }.value
                } catch is CancellationError {
                    return
                } catch {
                    print("Error loading directory: \(error)")
                }

                guard !Task.isCancelled, currentGeneration == loadGeneration else { return }

                await MainActor.run {
                    guard currentGeneration == loadGeneration else { return }
                    items = loadedItems
                    isLoading = false
                    didApplyItems = true
                    fileListFocusToken &+= 1
                    applyPendingExternalSelectionIfNeeded(
                        loadedItems: loadedItems,
                        for: currentPath
                    )
                }

                await MainActor.run {
                    DirectoryFSEventsMonitor.shared.stop()
                }
                if !invalidatingPaths.isEmpty {
                    await DirectoryMetadataScheduler.invalidate(paths: invalidatingPaths)
                }
                await DirectoryMetadataScheduler.resetSession(generation: currentGeneration)

                let folderPaths = loadedItems
                    .filter(\.isDirectory)
                    .map(\.id)
                await DirectoryMetadataScheduler.scheduleAfterListingLoad(
                    folderPaths: folderPaths,
                    showHiddenFiles: shouldShowHiddenFiles,
                    includeSizes: false
                )
                await MainActor.run {
                    guard currentGeneration == loadGeneration else { return }
                    updateDirectoryFSEventsMonitoring(
                        directoryPath: currentPath,
                        folderPaths: folderPaths,
                        showHiddenFiles: shouldShowHiddenFiles
                    )
                }
                return
            }
            
            await MainActor.run {
                DirectoryFSEventsMonitor.shared.stop()
            }
            
            if !invalidatingPaths.isEmpty {
                await DirectoryMetadataScheduler.invalidate(paths: invalidatingPaths)
            }
            await DirectoryMetadataScheduler.resetSession(generation: currentGeneration)
            
            var loadedItems: [FileItem] = []
            
            if TrashLoader.isTrashPath(currentPath) {
                loadedItems = await TrashLoader.loadItems(showHiddenFiles: shouldShowHiddenFiles)
            } else {
                do {
                    loadedItems = try await Task.detached(priority: .userInitiated) {
                        try DirectoryListingLoader.loadFileItems(
                            at: currentPath,
                            showHiddenFiles: shouldShowHiddenFiles,
                            options: listingOptions,
                            onEachURL: { _ in try Task.checkCancellation() }
                        )
                    }.value
                } catch is CancellationError {
                    return
                } catch {
                    print("Error loading directory: \(error)")
                }
            }
            
            guard !Task.isCancelled, currentGeneration == loadGeneration else { return }
            
            await MainActor.run {
                guard currentGeneration == loadGeneration else { return }
                items = loadedItems
                isLoading = false
                didApplyItems = true
                fileListFocusToken &+= 1
                applyPendingExternalSelectionIfNeeded(
                    loadedItems: loadedItems,
                    for: currentPath
                )
            }
            
            guard !Task.isCancelled, currentGeneration == loadGeneration else { return }
            
            let folderPaths = loadedItems
                .filter(\.isDirectory)
                .map(\.id)
            await DirectoryMetadataScheduler.scheduleAfterListingLoad(
                folderPaths: folderPaths,
                showHiddenFiles: shouldShowHiddenFiles,
                includeSizes: shouldAutoCalculateDirectorySizes(for: currentPath)
            )
            
            await MainActor.run {
                guard currentGeneration == loadGeneration else { return }
                updateDirectoryFSEventsMonitoring(
                    directoryPath: currentPath,
                    folderPaths: folderPaths,
                    showHiddenFiles: shouldShowHiddenFiles
                )
            }
        }
    }
    
    private func shouldAutoCalculateDirectorySizes(for directoryPath: String) -> Bool {
        autoCalculateDirectorySizes
            && !TrashLoader.isTrashPath(directoryPath)
            && DirectorySizeVolumeFilter.shouldAutoCalculate(path: directoryPath)
    }

    private func handleVolumeUnmount(volumePath: String) {
        guard let fallbackPath = RemoteVolumeUnmountHandler.resolveFallbackPath(
            from: path,
            unmountedVolumePath: volumePath
        ) else { return }
        showTransientNotice(L10n.RemoteServer.disconnectedFromServer)
        path = fallbackPath
    }

    private func showTransientNotice(_ message: String) {
        transientNoticeMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if transientNoticeMessage == message {
                    transientNoticeMessage = nil
                }
            }
        }
    }
    
    private func updateDirectoryFSEventsMonitoring(
        directoryPath: String,
        folderPaths: [String],
        showHiddenFiles: Bool
    ) {
        guard !TrashLoader.isTrashPath(directoryPath) else {
            DirectoryFSEventsMonitor.shared.stop()
            return
        }
        DirectoryFSEventsMonitor.shared.updateSession(
            directoryPath: directoryPath,
            folderPaths: folderPaths,
            showHiddenFiles: showHiddenFiles,
            autoCalculateDirectorySizes: shouldAutoCalculateDirectorySizes(for: directoryPath),
            onListingRefresh: { loadItems() }
        )
    }
    
    private func scheduleVisibleDirectorySizes(_ visiblePaths: [String]) {
        guard shouldAutoCalculateDirectorySizes(for: path) else { return }
        Task {
            await DirectoryMetadataScheduler.scheduleVisibleMetadata(
                visiblePaths: visiblePaths,
                showHiddenFiles: showHiddenFiles,
                includeSizes: true,
                includeItemCounts: false
            )
        }
    }

    private func scheduleVisibleDirectoryItemCounts(_ visiblePaths: [String]) {
        guard fileListViewMode == .thumbnail,
              !TrashLoader.isTrashPath(path) else { return }
        Task {
            await DirectoryMetadataScheduler.scheduleVisibleMetadata(
                visiblePaths: visiblePaths,
                showHiddenFiles: showHiddenFiles,
                includeSizes: false,
                includeItemCounts: true
            )
        }
    }
    
    private func handleFileListItemsChanged(_ invalidatedPaths: [String]) {
        selection.removeAll()
        loadItems(invalidatingPaths: invalidatedPaths)
    }
    
    private func handleAutoCalculateDirectorySizesChanged(_ enabled: Bool) {
        let folderPaths = items.filter(\.isDirectory).map(\.id)
        if enabled {
            rescheduleDirectorySizesIfNeeded()
        } else {
            loadGeneration += 1
            directoryMetadataOverlay.beginSizeSession(generation: loadGeneration)
            Task {
                await DirectorySizeService.shared.resetSession(generation: loadGeneration)
            }
        }
        updateDirectoryFSEventsMonitoring(
            directoryPath: path,
            folderPaths: folderPaths,
            showHiddenFiles: showHiddenFiles
        )
    }
    
    private func rescheduleDirectorySizesIfNeeded() {
        guard shouldAutoCalculateDirectorySizes(for: path) else { return }
        let folderPaths = items.filter(\.isDirectory).map(\.id)
        let shouldShowHiddenFiles = showHiddenFiles
        Task {
            await DirectoryMetadataScheduler.scheduleDirectorySizes(
                paths: folderPaths,
                showHiddenFiles: shouldShowHiddenFiles,
                priority: .normal
            )
        }
    }
    
    private var blankDoubleClickAction: BlankDoubleClickAction {
        BlankDoubleClickAction(rawValue: blankDoubleClickActionRaw) ?? .navigateToParent
    }
    
    private func handleBlankDoubleClick() {
        switch blankDoubleClickAction {
        case .navigateToParent:
            navigateUp()
        case .openTerminal:
            TerminalHelper.open(at: path)
        }
    }
    
    private var canNavigateBack: Bool {
        pathNavigation.canGoBack
    }

    private var canNavigateForward: Bool {
        pathNavigation.canGoForward
    }

    private func navigateBack() {
        var history = pathNavigation
        guard let previous = history.goBack(from: path) else { return }
        pathNavigation = history
        isApplyingHistoryNavigation = true
        path = previous
    }

    private func navigateForward() {
        var history = pathNavigation
        guard let next = history.goForward(from: path) else { return }
        pathNavigation = history
        isApplyingHistoryNavigation = true
        path = next
    }

    private func navigateToHistoryPath(_ targetPath: String) {
        let standardizedTarget = (targetPath as NSString).standardizingPath
        let standardizedCurrent = (path as NSString).standardizingPath
        guard standardizedTarget != standardizedCurrent else { return }

        let trail = pathNavigation.trail(currentPath: path)
        if trail.contains(where: { ($0 as NSString).standardizingPath == standardizedTarget }) {
            var history = pathNavigation
            history.jump(to: targetPath, from: path)
            pathNavigation = history
            isApplyingHistoryNavigation = true
            path = targetPath
        } else {
            path = targetPath
        }
    }
    
    private func navigateUp() {
        if TrashLoader.isTrashPath(path) {
            path = FileManager.default.homeDirectoryForCurrentUser.path
            return
        }
        
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        if parent != path {
            path = parent
        }
    }
    
    private func openItem(_ item: FileItem) {
        if item.isParentDirectoryEntry {
            navigateUp()
            return
        }
        FileOperations.open([item]) { path = $0 }
    }
    
    private var selectedItems: [FileItem] {
        filteredItems.filter { selection.contains($0.id) }
    }

    private var deletableSelectedItems: [FileItem] {
        selectedItems.filter { !$0.isParentDirectoryEntry }
    }

    private func deleteSelectedItems() {
        let items = deletableSelectedItems
        guard !items.isEmpty else { return }
        let paths = items.map(\.id)
        if TrashLoader.isTrashPath(path) {
            FileOperations.deleteImmediately(items) {
                selection.removeAll()
                loadItems(invalidatingPaths: paths)
            }
        } else {
            FileOperations.delete(items) {
                selection.removeAll()
                loadItems(invalidatingPaths: paths)
            }
        }
    }
    
    private var fileCommandHandlers: FileCommandHandlers {
        let selected = selectedItems
        let destPath = FileOperations.pasteDestination(
            selectedItems: selected,
            currentDirectoryPath: path
        )
        return FileCommandHandlers(
            copy: { FileOperations.copy(selected) },
            cut: { FileOperations.cut(selected) },
            paste: {
                FileOperations.paste(to: URL(fileURLWithPath: destPath)) {
                    selection.removeAll()
                    loadItems()
                }
            },
            delete: deleteSelectedItems,
            canCopy: !selected.isEmpty,
            canCut: !selected.isEmpty,
            canPaste: FileOperations.canPaste(to: URL(fileURLWithPath: destPath)),
            canDelete: !deletableSelectedItems.isEmpty
        )
    }
    
    private var blankMenuActions: FileListBlankMenuActions {
        let inTrash = TrashLoader.isTrashPath(path)
        let isNetworkVolume = DirectorySizeVolumeFilter.isNetworkVolume(path: path)
        let pasteDestination = URL(fileURLWithPath: path, isDirectory: true)
        let canPaste = !inTrash && FileOperations.canPaste(to: pasteDestination)
        let serviceFileURLs: () -> [URL] = {
            let selected = FileItem.resolveSelection(ids: selection, from: items)
                .filter { !$0.isParentDirectoryEntry }
            if !selected.isEmpty {
                return selected.map(\.url)
            }
            return [URL(fileURLWithPath: path, isDirectory: true)]
        }
        
        return FileListBlankMenuActions(
            isEnabled: searchText.isEmpty,
            canGoBack: canNavigateBack,
            goBack: navigateBack,
            canGoUp: FileItem.canNavigateUp(from: path),
            goUp: navigateUp,
            canPaste: canPaste,
            paste: {
                FileOperations.paste(to: pasteDestination) {
                    selection.removeAll()
                    loadItems()
                }
            },
            newFolder: createNewFolder,
            newFile: createNewFile,
            openTerminal: { TerminalHelper.open(at: path) },
            isInTrash: inTrash,
            showRefresh: isNetworkVolume,
            refresh: { loadItems() },
            emptyTrash: {
                FileOperations.emptyTrash {
                    selection.removeAll()
                    loadItems()
                }
            },
            appendToMenu: { menu in
                let selectedItems = FileItem.resolveSelection(ids: selection, from: items)
                SnippetsContextMenuBuilder.appendSnippetsMenu(
                    to: menu,
                    cwd: path,
                    selectedItems: selectedItems,
                    showHiddenFiles: showHiddenFiles
                )
                FileServicesMenuSupport.appendToMenu(menu, fileURLs: serviceFileURLs())
            },
            serviceFileURLs: serviceFileURLs,
            popUpContextMenu: { menu, event, view, fileURLs in
                FileServicesMenuSupport.popUpContextMenu(menu, with: event, for: view, fileURLs: fileURLs)
            }
        )
    }
    
    private var fileContextActions: FileContextActions {
        let isNetworkVolume = DirectorySizeVolumeFilter.isNetworkVolume(path: path)
        return FileContextActions(
            open: { FileOperations.open([$0]) { path = $0 } },
            openWith: FileOperations.openWith,
            openWithApplication: FileOperations.openWithApplication,
            cut: FileOperations.cut,
            copy: FileOperations.copy,
            copyFilename: FileOperations.copyFilename,
            copyPaths: FileOperations.copyPaths,
            delete: { items in
                let paths = items.map(\.id)
                FileOperations.delete(items) {
                    selection.removeAll()
                    loadItems(invalidatingPaths: paths)
                }
            },
            rename: { item in
                FileListTableController.shared?.beginRename(itemID: item.id)
            },
            showInfo: FileOperations.showInfo,
            canPaste: { destPath in
                FileOperations.canPaste(to: URL(fileURLWithPath: destPath))
            },
            paste: { destPath in
                FileOperations.paste(to: URL(fileURLWithPath: destPath)) {
                    selection.removeAll()
                    loadItems()
                }
            },
            isFavorited: { FavoritesStore.shared.contains(path: $0.url.path) },
            addToFavorites: { FavoritesStore.shared.addDirectory(at: $0.url.path) },
            isInTrash: TrashLoader.isTrashPath(path),
            emptyTrash: {
                FileOperations.emptyTrash {
                    selection.removeAll()
                    loadItems()
                }
            },
            putBack: { items in
                FileOperations.putBack(items) {
                    selection.removeAll()
                    loadItems()
                }
            },
            deleteImmediately: { items in
                let paths = items.map(\.id)
                FileOperations.deleteImmediately(items) {
                    selection.removeAll()
                    loadItems(invalidatingPaths: paths)
                }
            },
            openTerminal: { item in
                let directoryPath = item.isDirectory
                    ? item.url.path
                    : item.url.deletingLastPathComponent().path
                TerminalHelper.open(at: directoryPath)
            },
            openInNewWindow: { item in
                let directoryPath: String?
                if item.isParentDirectoryEntry {
                    directoryPath = FileItem.parentDirectoryURL(from: path)?.path
                } else if item.isDirectory, item.url.pathExtension.lowercased() != "app" {
                    directoryPath = item.url.path
                } else {
                    directoryPath = nil
                }
                guard let directoryPath else { return }
                externalFolderOpenCenter.requestOpenInNewWindow(directoryPath: directoryPath)
            },
            showRefresh: isNetworkVolume,
            refresh: { loadItems() }
        )
    }
    
    private func createNewFolder() {
        let alert = NSAlert()
        alert.messageText = L10n.Dialog.newFolderTitle
        alert.informativeText = L10n.Dialog.newFolderMessage
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = L10n.Dialog.folderNamePlaceholder
        alert.accessoryView = textField
        
        alert.addButton(withTitle: L10n.Dialog.create)
        alert.addButton(withTitle: L10n.Action.cancel)
        
        alert.window.initialFirstResponder = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let folderName = textField.stringValue
            
            if !folderName.isEmpty {
                let folderURL = URL(fileURLWithPath: path).appendingPathComponent(folderName)
                
                do {
                    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
                    loadItems()
                } catch {
                    let errorAlert = NSAlert(error: error)
                    errorAlert.runModal()
                }
            }
        }
    }
    
    private func createNewFile() {
        let alert = NSAlert()
        alert.messageText = L10n.Dialog.newFileTitle
        alert.informativeText = L10n.Dialog.newFileMessage
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = L10n.Dialog.fileNamePlaceholder
        alert.accessoryView = textField
        
        alert.addButton(withTitle: L10n.Dialog.create)
        alert.addButton(withTitle: L10n.Action.cancel)
        
        alert.window.initialFirstResponder = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let fileName = textField.stringValue
            
            if !fileName.isEmpty {
                let fileURL = URL(fileURLWithPath: path).appendingPathComponent(fileName)
                
                guard FileManager.default.createFile(atPath: fileURL.path, contents: Data()) else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = L10n.Dialog.cannotCreateFile
                    errorAlert.informativeText = L10n.Dialog.cannotCreateFileMessage
                    errorAlert.runModal()
                    return
                }
                loadItems()
            }
        }
    }
}
private struct LeadingResizeDivider: NSViewRepresentable {
    var onResize: (CGFloat) -> Void
    var onDragEnded: (() -> Void)?
    
    func makeNSView(context: Context) -> ResizeDividerNSView {
        ResizeDividerNSView()
    }
    
    func updateNSView(_ nsView: ResizeDividerNSView, context: Context) {
        nsView.onResize = onResize
        nsView.onDragEnded = onDragEnded
    }
}
private struct HorizontalResizeDivider: NSViewRepresentable {
    @Binding var trailingWidth: CGFloat
    let minTrailingWidth: CGFloat
    let maxTrailingWidth: CGFloat
    var onDragEnded: (() -> Void)?
    
    func makeNSView(context: Context) -> ResizeDividerNSView {
        ResizeDividerNSView()
    }
    
    func updateNSView(_ nsView: ResizeDividerNSView, context: Context) {
        context.coordinator.configure(
            trailingWidth: $trailingWidth,
            minTrailingWidth: minTrailingWidth,
            maxTrailingWidth: maxTrailingWidth,
            onDragEnded: onDragEnded,
            view: nsView
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator {
        func configure(
            trailingWidth: Binding<CGFloat>,
            minTrailingWidth: CGFloat,
            maxTrailingWidth: CGFloat,
            onDragEnded: (() -> Void)?,
            view: ResizeDividerNSView
        ) {
            view.onResize = { delta in
                let newWidth = trailingWidth.wrappedValue - delta
                trailingWidth.wrappedValue = min(
                    max(newWidth, minTrailingWidth),
                    maxTrailingWidth
                )
            }
            view.onDragEnded = onDragEnded
        }
    }
}

private final class ResizeDividerNSView: NSView {
    var onResize: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    private var lastMouseX: CGFloat?
    private var trackingArea: NSTrackingArea?
    
    override var isOpaque: Bool { false }
    
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }
    
    override func mouseDown(with event: NSEvent) {
        lastMouseX = event.locationInWindow.x
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let lastX = lastMouseX else { return }
        let currentX = event.locationInWindow.x
        let delta = currentX - lastX
        lastMouseX = currentX
        onResize?(delta)
    }
    
    override func mouseUp(with event: NSEvent) {
        lastMouseX = nil
        onDragEnded?()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        let lineX = floor((bounds.width - 1) / 2)
        dirtyRect.intersection(NSRect(x: lineX, y: 0, width: 1, height: bounds.height)).fill()
    }
}
