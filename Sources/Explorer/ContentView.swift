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
    /// 侧栏等 AppKit 宿主改 `path` 时 SwiftUI `onChange` 可能不触发，须显式加载列表。
    func navigateToDirectory(_ targetPath: String) {
        selection.removeAll()
        if path != targetPath {
            path = targetPath
        }
        loadItems()
    }

    func applyExternalNavigationTarget(_ target: ExternalNavigationTarget) {
        pendingExternalSelectionPath = target.selectionPath.map {
            ExternalSelectionPathMatcher.standardizedPath($0)
        }
        if path == target.directoryPath {
            if applyExternalSelectionImmediatelyIfPossible() {
                return
            }
            if isLoading {
                return
            }
            loadItems()
        } else {
            path = target.directoryPath
        }
    }

    /// 目录列表已就绪时直接选中，避免重复 `loadItems`。
    @discardableResult
    private func applyExternalSelectionImmediatelyIfPossible() -> Bool {
        guard let selectionPath = pendingExternalSelectionPath else {
            return !items.isEmpty && !isLoading
        }
        guard !items.isEmpty, !isLoading else { return false }
        guard let item = ExternalSelectionPathMatcher.matchingItem(in: items, selectionPath: selectionPath) else {
            return false
        }
        selection = [item.id]
        pendingExternalSelectionPath = nil
        fileListFocusToken &+= 1
        return true
    }

    func applyPendingExternalSelectionIfNeeded(loadedItems: [FileItem], for directoryPath: String) {
        guard directoryPath == path else { return }
        guard let pendingExternalSelectionPath else { return }
        guard let item = ExternalSelectionPathMatcher.matchingItem(
            in: loadedItems,
            selectionPath: pendingExternalSelectionPath
        ) else {
            return
        }
        self.pendingExternalSelectionPath = nil
        selection = [item.id]
        fileListFocusToken &+= 1
    }

    func refreshListingItem(at filePath: String) {
        let standardizedPath = ExternalSelectionPathMatcher.standardizedPath(filePath)
        let parentDirectory = ExternalSelectionPathMatcher.standardizedPath(
            (standardizedPath as NSString).deletingLastPathComponent
        )
        guard ExternalSelectionPathMatcher.standardizedPath(path) == parentDirectory else { return }

        let listingOptions = DirectoryListingOptions.forPath(path)
        guard let refreshed = try? DirectoryListingIncrementalUpdate.loadFileItems(
            at: [URL(fileURLWithPath: standardizedPath)],
            showHiddenFiles: showHiddenFiles,
            options: listingOptions
        ).first else {
            return
        }

        guard items.contains(where: { $0.id == refreshed.id }) else { return }
        items = DirectoryListingIncrementalUpdate.merge(
            adding: [refreshed],
            removing: [],
            into: items,
            sort: FileListPreferencesStore.shared.sort
        )
    }

    func restoreSelectionAfterListingLoad(
        _ preservedSelection: Set<FileItem.ID>,
        loadedItems: [FileItem],
        shouldPreserve: Bool
    ) {
        guard shouldPreserve, !preservedSelection.isEmpty else { return }
        let restored = preservedSelection.filter { id in
            loadedItems.contains(where: { $0.id == id })
        }
        if !restored.isEmpty {
            selection = restored
        }
    }

    func applyPendingInlineRenameIfNeeded(loadedItems: [FileItem], for directoryPath: String) {
        guard directoryPath == path else { return }
        guard let renamePath = pendingInlineRenamePath else { return }
        guard loadedItems.contains(where: { $0.id == renamePath }) else { return }
        pendingInlineRenamePath = nil
        selection = [renamePath]
        switch fileListViewMode {
        case .list:
            FileListTableController.shared?.scheduleRenameAfterListingUpdate(itemID: renamePath)
        case .thumbnail:
            FileListThumbnailController.shared?.scheduleRenameAfterListingUpdate(itemID: renamePath)
        }
    }

    private func applyPendingExternalNavigationForNewTab(_ navigation: ExplorerWindowTabCenter.PendingMainTabNavigation) {
        pendingExternalSelectionPath = navigation.selectionPath.map {
            ExternalSelectionPathMatcher.standardizedPath($0)
        }
        if path != navigation.path {
            path = navigation.path
            return
        }
        if !applyExternalSelectionImmediatelyIfPossible(), !isLoading {
            loadItems()
        }
    }

    func applyExternalOpenRequestIfNeeded() {
        guard windowSceneKind == .main else { return }
        guard let request = externalFolderOpenCenter.targetRequest else { return }
        guard hostWindow != nil else { return }
        applyExternalNavigationTarget(ExternalNavigationTarget(request: request))
    }

    private func applyLaunchNavigation(_ request: ExternalFolderOpenCenter.OpenRequest) {
        pendingExternalSelectionPath = request.selectionPath.map {
            ExternalSelectionPathMatcher.standardizedPath($0)
        }
        let directory = request.directoryPath
        if path != directory {
            path = directory
        } else if !applyExternalSelectionImmediatelyIfPossible(), !isLoading {
            loadItems()
        }
    }
}
struct ContentView: View {
    private let initialPath: String?
    private let initialSelectionPath: String?
    private let windowSceneKind: ExplorerWindowSceneKind

    @Environment(\.openWindow) private var openWindow
    @StateObject private var layout = ExplorerWindowLayoutState()
    @StateObject private var gitStatusStore = GitStatusStore()
    @AppStorage("blankDoubleClickAction")
    private var blankDoubleClickActionRaw = BlankDoubleClickAction.navigateToParent.rawValue
    @AppStorage(AppPreferences.Preview.doubleClickAction)
    private var previewDoubleClickActionRaw = PreviewDoubleClickAction.defaultValue.rawValue
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
    @AppStorage(AppPreferences.Directory.autoCalculateDirectorySizes) private var autoCalculateDirectorySizes = false
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
    @ObservedObject private var shortcutSettings = ShortcutSettingsStore.shared
    @ObservedObject private var windowTabCenter = ExplorerWindowTabCenter.shared
    @ObservedObject private var detachCoordinator = PreviewDetachCoordinator.shared
    @State private var explorerTabBarState = ExplorerTabBarState.unavailable
    @State private var pendingExternalSelectionPath: String?
    @State private var pendingInlineRenamePath: String?
    @State private var showConnectServerSheet = false
    @State private var transientNoticeMessage: String?
    @ObservedObject private var pasteboardAvailability = PasteboardPasteAvailability.shared
    @ObservedObject private var pasteOperationCenter = PasteOperationCenter.shared
    @StateObject private var operationRecorder = OperationRecorder()
    @State private var operationRecordingCloseGuard = OperationRecordingWindowCloseGuard()
    @State private var operationRecordingReview: OperationRecordingReviewContext?
    @State private var showDiscardRecordingConfirm = false
    @State private var lastHandledOpenRequestGeneration: UInt = 0
    @State private var isCommandPalettePresented = false
    @State private var commandPaletteSession: CommandPaletteSession?
    @StateObject private var contentSearchSession = DirectoryContentSearchSession()
    @AppStorage(AppPreferences.Search.mode) private var searchModeRaw = DirectorySearchMode.filename.rawValue
    @State private var contentQuery = ""
    @State private var isContentSearchFilterExpanded = false
    
    init(
        initialPath: String? = nil,
        initialSelectionPath: String? = nil,
        windowSceneKind: ExplorerWindowSceneKind = .main
    ) {
        self.initialPath = initialPath
        self.initialSelectionPath = initialSelectionPath
        self.windowSceneKind = windowSceneKind
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
            let containerWidth = outer.size.width
            let maxPreviewWidth = max(
                minPreviewPanelWidth,
                containerWidth - minMainPanelWidth
            )
            let outputMaxHeight = OutputPanelMetrics.maxPanelHeight(forContainerHeight: containerHeight)

            HStack(spacing: 0) {
                if leftPanelMode != .hidden {
                    Group {
                        Group {
                            switch leftPanelMode {
                            case .sidebar:
                                SidebarView(
                                    path: $path,
                                    onNavigateToDirectory: navigateToDirectory,
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
                                    onNavigateToDirectory: navigateToDirectory,
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
                        .frame(width: HorizontalResizeDividerMetrics.hitWidth)
                        .padding(.horizontal, -(HorizontalResizeDividerMetrics.hitWidth - HorizontalResizeDividerMetrics.visualWidth) / 2)
                        .frame(maxHeight: .infinity)
                    }
                    .animation(nil, value: liveLeftPanelDragWidth)
                }

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        explorerBrowserColumn

                        if layout.showPreview || layout.showSnippets || layout.showGit {
                            explorerRightPanelColumn(maxPreviewWidth: maxPreviewWidth)
                        }
                    }
                    .animation(nil, value: livePreviewPanelWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onAppear {
                        livePreviewPanelWidth = clampPreviewWidth(
                            CGFloat(layout.previewPanelWidth),
                            maxWidth: maxPreviewWidth
                        )
                    }
                    .onChange(of: containerWidth) { newWidth in
                        let maxPreview = max(minPreviewPanelWidth, newWidth - minMainPanelWidth)
                        let clamped = clampPreviewWidth(livePreviewPanelWidth, maxWidth: maxPreview)
                        if clamped != livePreviewPanelWidth {
                            livePreviewPanelWidth = clamped
                            layout.previewPanelWidth = Double(clamped)
                        }
                    }

                    OutputPanelView(
                        layout: layout,
                        containerHeight: containerHeight,
                        maxPanelHeight: outputMaxHeight,
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: outer.size.width, height: outer.size.height)
            .background(
                CommandPalettePreviewCommandCapture(hostWindowID: previewHostWindowID)
            )
            .overlay(alignment: .top) {
                PanelToolbarBottomSeparatorOverlay()
                    .frame(height: PanelSeparatorStyle.toolbarSeparatorMaskHeight)
                    .allowsHitTesting(false)
            }
            .focusedValue(\.textFieldEditing, isAnyTextFieldEditing)
            .background(TextEditingKeyMonitor(isActive: isAnyTextFieldEditing))
        }
        .background(WindowKeyLayoutTracker(layout: layout).frame(width: 0, height: 0).accessibilityHidden(true))
        .background(
            HostWindowReader(
                window: $hostWindow,
                onWindowAttached: { window in
                    ExplorerWindowTabCenter.shared.configureExplorerWindow(window)
                    ExplorerWindowTabCenter.shared.attemptTabMerge(for: window)
                }
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
        .onChange(of: hostWindow) { window in
            guard let window else {
                PreviewHostWindowRegistry.shared.unregister(hostWindowID: previewHostWindowID)
                operationRecordingCloseGuard.detach()
                return
            }
            ExplorerWindowTabCenter.shared.configureExplorerWindow(window)
            ExplorerWindowTabCenter.shared.attemptTabMerge(for: window)
            if let navigation = ExplorerWindowTabCenter.shared.consumeInitialNavigationForNewTab(in: window) {
                applyPendingExternalNavigationForNewTab(navigation)
            }
            ExplorerWindowTabCenter.shared.registerWindow(window, path: path, sceneKind: windowSceneKind)
            ExplorerWindowTabCenter.shared.handleExplorerWindowDidAppear(window)
            PreviewHostWindowRegistry.shared.register(hostWindowID: previewHostWindowID, window: window)
            syncExplorerTabBarState()
            applyExternalOpenRequestIfNeeded()
            _ = applyExternalSelectionImmediatelyIfPossible()
            OperationRecordingHub.register(operationRecorder)
            operationRecordingCloseGuard.attach(
                to: window,
                recorder: operationRecorder,
                onStopAndGenerate: { steps, cwd in
                    presentOperationRecordingReview(
                        steps: steps,
                        recordingCWD: cwd.isEmpty ? path : cwd
                    )
                }
            )
        }
        .onChange(of: path) { newPath in
            guard let hostWindow else { return }
            ExplorerWindowTabCenter.shared.registerWindow(hostWindow, path: newPath, sceneKind: windowSceneKind)
            gitStatusStore.scheduleRefresh(cwd: newPath)
            updateGitWorkspaceFSEventsMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .gitWorkingTreeMayHaveChanged)) { notification in
            guard let changedPath = notification.userInfo?[GitWorkingTreeRefreshCenter.pathUserInfoKey] as? String,
                  let currentRoot = GitRepositoryDetector.findRepoRoot(from: path),
                  let changedRoot = GitRepositoryDetector.findRepoRoot(from: changedPath),
                  GitRepositoryDetector.rootsEqual(currentRoot, changedRoot) else { return }
            gitStatusStore.scheduleRefresh(cwd: path)
        }
        .onReceive(NotificationCenter.default.publisher(for: .directoryListingItemDidChange)) { notification in
            guard let changedPath = notification.userInfo?[DirectoryListingItemRefreshCenter.pathUserInfoKey] as? String else {
                return
            }
            refreshListingItem(at: changedPath)
        }
        .onChange(of: windowTabCenter.tabBarRevision) { _ in
            syncExplorerTabBarState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let keyWindow = notification.object as? NSWindow,
                  keyWindow == hostWindow else { return }
            OperationRecordingHub.register(operationRecorder)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closingWindow = notification.object as? NSWindow,
                  closingWindow == hostWindow else { return }
            PreviewHostWindowRegistry.shared.unregister(hostWindowID: previewHostWindowID)
            PreviewDetachCoordinator.shared.onHostWindowWillClose(hostWindowID: previewHostWindowID)
        }
        .background(
            BarFieldOutsideClickHandler(
                activeField: $activeBarField,
                isPathBarTextMode: $isPathBarTextMode,
                tableItems: fileListTableItems
            )
        )
        .onAppear {
            toolbarStore.loadIfNeeded()

            if let mapped = fileListPreferences.sort.explorerSortOrder {
                sortOrder = mapped
            }
            
            // 初始化时做一次自愈：持久化宽度可能越界。
            layout.healLeftPanelSidebarWidth()
            gitStatusStore.scheduleRefresh(cwd: path)
            if let initialPath {
                path = initialPath
                pendingExternalSelectionPath = initialSelectionPath.map {
                    ExternalSelectionPathMatcher.standardizedPath($0)
                }
                loadItems()
            } else if windowSceneKind == .main {
                let launchRequest = externalFolderOpenCenter.consumePendingRequest()
                    ?? externalFolderOpenCenter.targetRequest
                if let launchRequest {
                    applyLaunchNavigation(launchRequest)
                } else {
                    path = restoredLaunchPath()
                    loadItems()
                }
            } else {
                path = restoredLaunchPath()
                loadItems()
            }
            lastRecordedPath = path
            layout.recordLastOpenedPath(path)
            syncExplorerTabBarState()
            externalFolderOpenCenter.markSessionEstablished()
            lastHandledOpenRequestGeneration = externalFolderOpenCenter.openRequestGeneration
            applyExternalOpenRequestIfNeeded()
            if let hostWindow {
                ExplorerWindowTabCenter.shared.registerWindow(
                    hostWindow,
                    path: path,
                    sceneKind: windowSceneKind
                )
            }
        }
        .onDisappear {
            OperationRecordingHub.unregister(operationRecorder)
            operationRecordingCloseGuard.detach()
        }
        .onReceive(externalFolderOpenCenter.$openRequestGeneration) { generation in
            guard generation > lastHandledOpenRequestGeneration else { return }
            lastHandledOpenRequestGeneration = generation
            applyExternalOpenRequestIfNeeded()
        }
        .onChange(of: isLoading) { loading in
            guard !loading else { return }
            _ = applyExternalSelectionImmediatelyIfPossible()
        }
        .onChange(of: connectServerCenter.presentSheetToken) { _ in
            guard hostWindow == NSApp.keyWindow else { return }
            showConnectServerSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandPaletteToggleRequested)) { _ in
            guard hostWindow == NSApp.keyWindow else { return }
            toggleCommandPalette()
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
        .sheet(item: $operationRecordingReview) { context in
            OperationRecordingReviewSheet(context: context) { snippet in
                SnippetStore.shared.add(snippet)
                layout.showSnippets = true
                showTransientNotice(L10n.OperationRecording.snippetSaved(snippet.name))
            }
        }
        .confirmationDialog(
            L10n.OperationRecording.discardConfirmTitle,
            isPresented: $showDiscardRecordingConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.OperationRecording.bannerDiscard, role: .destructive) {
                discardOperationRecording()
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.OperationRecording.discardConfirmMessage)
        }
        .onChange(of: path) { newPath in
            FileOperations.cancelActivePaste()
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
            resetContentSearchForPathChange()
            loadItems()
        }
        .onChange(of: contentQuery) { newValue in
            contentSearchSession.query = newValue
        }
        .onChange(of: searchModeRaw) { _ in
            handleDirectorySearchModeChange()
        }
        .onChange(of: showHiddenFiles) { _ in
            syncContentSearchContext()
        }
        .onAppear {
            loadPersistedContentSearchFilter()
            syncContentSearchContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .findInFolderRequested)) { _ in
            focusFindInFolder()
        }
        .onChange(of: contentSearchSession.filter) { filter in
            persistContentSearchFilter(filter)
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
        .onReceive(NotificationCenter.default.publisher(for: .archiveOperationCompleted)) { notification in
            guard let paths = notification.userInfo?[ArchiveOperationNotifications.resultPathsKey] as? [String] else {
                return
            }
            let navigateIntoResult = notification.userInfo?[ArchiveOperationNotifications.navigateIntoResultKey] as? Bool ?? false
            handleArchiveOperationCompleted(paths: paths, navigateIntoResult: navigateIntoResult)
        }
        .onChange(of: detachCoordinator.directoryItemsInvalidatedRevision) { _ in
            guard let event = detachCoordinator.lastDirectoryItemsInvalidatedEvent else { return }
            handleDirectoryItemsInvalidatedFromDetachedPreview(event)
        }
        .onChange(of: detachCoordinator.revealInHostRevision) { _ in
            guard let event = detachCoordinator.lastRevealInHostEvent else { return }
            handleRevealInHostFromDetachedPreview(event)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let pasteProgress = pasteOperationCenter.activeProgress {
                    pasteProgressBanner(pasteProgress)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let transientNoticeMessage {
                    Text(transientNoticeMessage)
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 12)
        }
        .animation(.easeInOut(duration: 0.2), value: transientNoticeMessage)
        .animation(.easeInOut(duration: 0.2), value: pasteOperationCenter.activeProgress)
        .overlay {
            if isCommandPalettePresented, let commandPaletteSession {
                CommandPaletteOverlay(
                    session: commandPaletteSession,
                    isPresented: $isCommandPalettePresented
                )
            }
        }
        .onChange(of: isCommandPalettePresented) { presented in
            if !presented {
                commandPaletteSession = nil
            }
        }
    }
    
    private var filteredItems: [FileItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var directorySearchMode: DirectorySearchMode {
        DirectorySearchMode(rawValue: searchModeRaw) ?? .filename
    }

    private var searchModeBinding: Binding<DirectorySearchMode> {
        Binding(
            get: { directorySearchMode },
            set: { searchModeRaw = $0.rawValue }
        )
    }

    private var shouldShowContentSearchResults: Bool {
        directorySearchMode == .content
            && !contentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func syncContentSearchContext() {
        contentSearchSession.updateSearchContext(
            root: URL(fileURLWithPath: path),
            showHiddenFiles: showHiddenFiles
        )
    }

    private func resetContentSearchForPathChange() {
        contentSearchSession.cancel()
        contentQuery = ""
        syncContentSearchContext()
    }

    private func handleDirectorySearchModeChange() {
        if directorySearchMode == .filename {
            contentQuery = ""
            contentSearchSession.cancel()
            isContentSearchFilterExpanded = false
        } else {
            searchText = ""
            syncContentSearchContext()
        }
    }

    private var isContentSearchActive: Bool {
        shouldShowContentSearchResults
    }

    private func dismissContentSearch() {
        contentSearchSession.cancelInFlightSearch()
        contentQuery = ""
    }

    private func focusFindInFolder() {
        searchModeRaw = DirectorySearchMode.content.rawValue
        activeBarField = .search
    }

    private func handleContentSearchMatchSelected(_ match: ContentSearchMatch) {
        selection = [match.fileURL.path]
        layout.showPreview = true
        ContentSearchRevealNotification.prepareReveal(
            ContentSearchRevealRequest(
                hostWindowID: previewHostWindowID,
                fileID: match.fileURL.path,
                lineNumber: match.lineNumber,
                query: contentQuery
            )
        )
    }

    private func loadPersistedContentSearchFilter() {
        guard let data = UserDefaults.standard.data(forKey: AppPreferences.Search.contentFilterJSON),
              let filter = try? JSONDecoder().decode(ContentSearchFilter.self, from: data) else {
            return
        }
        contentSearchSession.filter = filter
    }

    private func persistContentSearchFilter(_ filter: ContentSearchFilter) {
        guard let data = try? JSONEncoder().encode(filter) else { return }
        UserDefaults.standard.set(data, forKey: AppPreferences.Search.contentFilterJSON)
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

                GitPathBarChip(
                    gitStatusStore: gitStatusStore,
                    showGit: $layout.showGit,
                    cwd: path
                )
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .padding(.leading, 0)
            .padding(.trailing, 8)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)
            
            Divider()
            
            OperationRecordingBanner(
                recorder: operationRecorder,
                onStopAndGenerate: stopOperationRecordingAndReview,
                onDiscard: { showDiscardRecordingConfirm = true }
            )

            if directorySearchMode == .content, isContentSearchFilterExpanded {
                DirectoryContentSearchFilterBar(
                    session: contentSearchSession,
                    isExpanded: $isContentSearchFilterExpanded
                )
                Divider()
            }

            Group {
                if shouldShowContentSearchResults {
                    DirectoryContentSearchResultsView(
                        session: contentSearchSession,
                        onSelectMatch: { match in
                            handleContentSearchMatchSelected(match)
                        },
                        onShowPreview: {
                            layout.showPreview = true
                        },
                        onDismiss: dismissContentSearch
                    )
                } else {
                    explorerFileListSection
                }
            }
            .animation(.easeOut(duration: 0.15), value: shouldShowContentSearchResults)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .focusedValue(
            \.windowLayoutCommands,
            WindowLayoutCommands(
                showPreview: layout.showPreview,
                showSnippets: layout.showSnippets,
                showGit: layout.showGit,
                isOutputPanelVisible: layout.isOutputPanelVisible,
                toggleLeftPanel: { layout.toggleLeftPanelVisibility() },
                toggleRightPanel: { layout.toggleRightPanel() },
                togglePreview: { layout.showPreview.toggle() },
                toggleSnippets: { layout.showSnippets.toggle() },
                toggleGit: { layout.toggleGitPanel() },
                toggleOutputPanel: { layout.toggleOutputPanel() }
            )
        )
        .background(BarTextFieldFocusSync(activeField: $activeBarField))
        .navigationTitle(currentDirectoryTitle)
        .modifier(InlineToolbarTitleModifier())
        .modifier(HiddenToolbarChromeSeparatorModifier())
        .toolbar {
            ExplorerDynamicToolbar(
                store: toolbarStore,
                environment: toolbarEnvironment,
                searchContent: {
                    DirectoryContentSearchToolbarSearch(
                        searchMode: searchModeBinding,
                        searchText: $searchText,
                        contentQuery: $contentQuery,
                        activeBarField: $activeBarField,
                        isFilterExpanded: $isContentSearchFilterExpanded
                    )
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
                },
                onDeleteOpenShortcut: { action in
                    toolbarStore.deleteCustomOpenShortcut(id: action.id)
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

            Button(L10n.Search.findInFolder) {
                focusFindInFolder()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
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

            Button(L10n.Toolbar.showAllTabs) {
                showAllExplorerTabs()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.showAllTabs)
            .labelsHidden()
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            Button(L10n.Toolbar.newWindow) {
                openNewExplorerWindow()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.newWindow)
            .labelsHidden()
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            LocalShortcutMonitor(
                binding: ShortcutBinding(keyCode: 45, modifiers: .command),
                isEnabled: !isAnyTextFieldEditing
            ) {
                openNewExplorerWindow()
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            LocalShortcutMonitor(
                binding: shortcutSettings.newTabBinding,
                isEnabled: !isAnyTextFieldEditing
            ) {
                openNewExplorerTab()
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            LocalShortcutMonitor(
                binding: shortcutSettings.copyPathBinding,
                isEnabled: !isAnyTextFieldEditing
            ) {
                let selected = selectedItems
                guard !selected.isEmpty else { return }
                FileOperations.copyPaths(selected)
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            Button(L10n.CommandPalette.menuTitle) {
                toggleCommandPalette()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.commandPalette)
            .labelsHidden()
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    private func toggleCommandPalette() {
        if isCommandPalettePresented {
            withAnimation(.easeOut(duration: 0.15)) {
                isCommandPalettePresented = false
            }
            commandPaletteSession = nil
            return
        }

        isQuickSearchVisible = false
        quickSearchText = ""
        let previewCommands = CommandPalettePreviewCommandBridge.shared.commands(for: previewHostWindowID)
        let context = makeCommandPaletteContext(
            previewDetach: previewCommands.detach,
            previewBrowse: previewCommands.browse
        )
        commandPaletteSession = CommandPaletteSession(context: context)
        withAnimation(.easeOut(duration: 0.15)) {
            isCommandPalettePresented = true
        }
    }

    private func makeCommandPaletteContext(
        previewDetach: PreviewDetachCommands?,
        previewBrowse: PreviewBrowseCommands?
    ) -> CommandPaletteContext {
        CommandPaletteContext(
            currentPath: path,
            selectedItems: selectedItems,
            deletableSelectedItems: deletableSelectedItems,
            layout: layout,
            toolbarEnvironment: toolbarEnvironment,
            fileHandlers: fileCommandHandlers,
            fileActions: fileContextActions,
            blankMenuActions: blankMenuActions,
            previewDetach: previewDetach,
            previewBrowse: previewBrowse,
            tabBarState: explorerTabBarState,
            showHiddenFiles: showHiddenFiles,
            canNavigateBack: canNavigateBack,
            canNavigateForward: canNavigateForward,
            canNavigateUp: FileItem.canNavigateUp(from: path),
            focusSearch: { activeBarField = .search },
            focusFindInFolder: focusFindInFolder,
            navigateBack: navigateBack,
            navigateForward: navigateForward,
            navigateUp: navigateUp,
            presentConnectServer: { showConnectServerSheet = true },
            openSettings: { SettingsWindowPresenter.shared.show() },
            openHelp: { HelpWindowPresenter.shared.show() },
            customizeToolbar: {
                ToolbarCustomizationWindowController.present(
                    store: toolbarStore,
                    environment: toolbarEnvironment,
                    parentWindow: hostWindow
                )
            },
            toggleCommandPalette: toggleCommandPalette,
            importSnippets: {
                NotificationCenter.default.post(name: .snippetsImportRequested, object: nil)
            },
            exportSnippets: {
                NotificationCenter.default.post(name: .snippetsExportAllRequested, object: nil)
            },
            focusOutputCommand: {
                if !layout.isOutputPanelVisible {
                    layout.toggleOutputPanel()
                }
                if layout.isOutputPanelContentCollapsed {
                    layout.isOutputPanelContentCollapsed = false
                }
                NotificationCenter.default.post(name: .outputCommandFocusRequested, object: nil)
            }
        )
    }

    private func openNewExplorerWindow() {
        ExplorerWindowTabCenter.shared.openNewWindow(path: path, from: hostWindow)
    }

    private func openNewExplorerTab() {
        ExplorerWindowTabCenter.shared.openNewTab(path: path, from: hostWindow)
    }

    private func showAllExplorerTabs() {
        ExplorerWindowTabCenter.shared.showAllTabs(in: hostWindow)
    }

    private func toggleExplorerTabBar() {
        ExplorerWindowTabCenter.shared.toggleTabBar(in: hostWindow)
        syncExplorerTabBarState()
    }

    private func syncExplorerTabBarState() {
        explorerTabBarState = ExplorerWindowTabCenter.tabBarState(for: hostWindow)
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
            tabBarState: explorerTabBarState,
            isOperationRecording: operationRecorder.isRecording,
            toggleLeftPanelVisibility: toggleLeftPanelVisibility,
            openNewWindow: openNewExplorerWindow,
            openNewTab: openNewExplorerTab,
            showAllTabs: showAllExplorerTabs,
            toggleTabBar: toggleExplorerTabBar,
            createNewFolder: createNewFolder,
            createNewFile: createNewFile,
            deleteSelectedItems: deleteSelectedItems,
            toggleHiddenFiles: {
                showHiddenFiles.toggle()
                loadItems()
            },
            setSortOrder: { sortOrder = $0 },
            toggleAutoCalculateDirectorySizes: { autoCalculateDirectorySizes.toggle() },
            toggleUseIconPreview: { useIconPreview.toggle() },
            performOpenApp: performToolbarOpenApp,
            editOpenApp: editToolbarOpenApp,
            performOpenShortcut: performToolbarOpenShortcut,
            toggleOperationRecording: toggleOperationRecording
        )
    }

    private func toggleOperationRecording() {
        if operationRecorder.isRecording {
            stopOperationRecordingAndReview()
        } else {
            operationRecorder.start(cwd: path)
            OperationRecordingHub.register(operationRecorder)
        }
    }

    private func stopOperationRecordingAndReview() {
        let cwd = operationRecorder.recordingStartCWD ?? path
        let steps = operationRecorder.stop()
        presentOperationRecordingReview(steps: steps, recordingCWD: cwd)
    }

    private func discardOperationRecording() {
        operationRecorder.discard()
        showTransientNotice(L10n.OperationRecording.discarded)
    }

    private func presentOperationRecordingReview(
        steps: [RecordedOperationStep],
        recordingCWD: String
    ) {
        guard !steps.isEmpty else {
            showTransientNotice(L10n.OperationRecording.noSteps)
            return
        }
        operationRecordingReview = OperationRecordingReviewContext(
            steps: steps,
            recordingCWD: recordingCWD,
            recordedAt: Date(),
            isInTrash: TrashLoader.isTrashPath(recordingCWD)
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

    private func performToolbarOpenShortcut(_ action: CustomOpenShortcutAction) {
        do {
            try OpenShortcutExecutor.run(action, navigate: { path = $0 })
        } catch ToolbarActionError.shortcutMissing(let name) {
            OpenShortcutExecutor.presentMissingAlert(name: name) {
                toolbarStore.deleteCustomOpenShortcut(id: action.id)
            }
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
        .frame(width: HorizontalResizeDividerMetrics.hitWidth)
        .padding(.horizontal, -(HorizontalResizeDividerMetrics.hitWidth - HorizontalResizeDividerMetrics.visualWidth) / 2)
        .frame(maxHeight: .infinity)
        
        RightPanelStackView(
            layout: layout,
            gitStatusStore: gitStatusStore,
            hostWindowID: previewHostWindowID,
            selection: $selection,
            items: items,
            cwd: path,
            sortOrder: sortOrder,
            showHiddenFiles: showHiddenFiles,
            autoCalculateDirectorySizes: shouldAutoCalculateDirectorySizes(for: path),
            directoryMetadataOverlay: directoryMetadataOverlay,
            panelWidth: livePreviewPanelWidth,
            onNavigate: { path = $0 },
            onOpenItem: { openItem($0) },
            onOpenTerminalAtPath: { TerminalHelper.open(at: $0) },
            onRevealGitPath: revealGitPathInFileList
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
            isContentSearchActive: isContentSearchActive,
            quickSearchText: $quickSearchText,
            isQuickSearchVisible: $isQuickSearchVisible,
            isFileListRenaming: $isFileListRenaming,
            focusToken: fileListFocusToken,
            currentDirectoryPath: path,
            canNavigateToParent: FileItem.canNavigateUp(from: path),
            showHiddenFiles: showHiddenFiles,
            directoryMetadataOverlay: directoryMetadataOverlay,
            viewMode: fileListViewMode,
            thumbnailLayoutMode: layout.thumbnailLayoutMode,
            panoramaExpandDepthPolicy: layout.panoramaExpandDepthPolicy,
            thumbnailCellSize: thumbnailCellSize,
            useIconPreview: useIconPreview && !isNetworkVolume,
            preferWorkspaceIconsInThumbnail: isNetworkVolume,
            isLoading: isLoading,
            onThumbnailCellSizeChange: { layout.thumbnailCellSizeValue = $0 },
            onItemOpen: { item, openInDetachedPreview in
                openItem(item, openInDetachedPreview: openInDetachedPreview)
            },
            onBlankDoubleClick: handleBlankDoubleClick,
            onItemsChanged: handleFileListItemsChanged,
            onScheduleVisibleDirectorySizes: scheduleVisibleDirectorySizes,
            onScheduleVisibleDirectoryItemCounts: scheduleVisibleDirectoryItemCounts,
            contextActions: fileContextActions,
            blankMenuActions: blankMenuActions,
            canNavigateBack: canNavigateBack,
            onNavigateBack: navigateBack,
            onNavigateToDirectory: navigateToDirectory
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
        let shouldPreserveSelection = !items.isEmpty
        let preservedSelection = shouldPreserveSelection ? selection : []
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
                    applyPendingInlineRenameIfNeeded(
                        loadedItems: loadedItems,
                        for: currentPath
                    )
                    if pendingExternalSelectionPath == nil, pendingInlineRenamePath == nil {
                        restoreSelectionAfterListingLoad(
                            preservedSelection,
                            loadedItems: loadedItems,
                            shouldPreserve: shouldPreserveSelection
                        )
                    }
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
                    updateGitWorkspaceFSEventsMonitoring(for: currentPath)
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
                applyPendingInlineRenameIfNeeded(
                    loadedItems: loadedItems,
                    for: currentPath
                )
                if pendingExternalSelectionPath == nil, pendingInlineRenamePath == nil {
                    restoreSelectionAfterListingLoad(
                        preservedSelection,
                        loadedItems: loadedItems,
                        shouldPreserve: shouldPreserveSelection
                    )
                }
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
                updateGitWorkspaceFSEventsMonitoring(for: currentPath)
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

    @ViewBuilder
    private func pasteProgressBanner(_ progress: PasteOperationCenter.ActiveProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(progress.message)
                .font(.callout)
                .lineLimit(2)
            if progress.showsDeterminateProgress, let fraction = progress.progressFraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            onListingPatch: { patch in
                applyIncrementalListingPatch(patch)
            },
            onListingRefresh: { loadItems() }
        )
    }

    private func applyIncrementalListingPatch(_ patch: DirectoryListingIncrementalPatcher.Patch) {
        let removed = Set(patch.removedPaths)
        if !removed.isEmpty {
            items = DirectoryListingIncrementalUpdate.merge(
                adding: [],
                removing: removed,
                into: items,
                sort: FileListPreferencesStore.shared.sort
            )
            selection.subtract(removed)
        }

        guard !patch.addedPaths.isEmpty else { return }

        let urls = patch.addedPaths.map { URL(fileURLWithPath: $0) }
        let currentPath = path
        let shouldShowHiddenFiles = showHiddenFiles
        let listingOptions = DirectoryListingOptions.forPath(currentPath)
        let sort = FileListPreferencesStore.shared.sort

        Task {
            let addedItems = await Task.detached(priority: .userInitiated) {
                (try? DirectoryListingIncrementalUpdate.loadFileItems(
                    at: urls,
                    showHiddenFiles: shouldShowHiddenFiles,
                    options: listingOptions
                )) ?? []
            }.value

            await MainActor.run {
                guard !addedItems.isEmpty else { return }
                items = DirectoryListingIncrementalUpdate.merge(
                    adding: addedItems,
                    removing: [],
                    into: items,
                    sort: sort
                )
                scheduleMetadataForInsertedFolders(addedItems, in: currentPath)
            }
        }
    }

    private func scheduleMetadataForInsertedFolders(_ addedItems: [FileItem], in directoryPath: String) {
        let newFolders = addedItems.filter(\.isDirectory).map(\.id)
        guard !newFolders.isEmpty else { return }
        Task {
            await DirectoryMetadataScheduler.scheduleAfterListingLoad(
                folderPaths: newFolders,
                showHiddenFiles: showHiddenFiles,
                includeSizes: shouldAutoCalculateDirectorySizes(for: directoryPath)
            )
        }
        updateDirectoryFSEventsMonitoring(
            directoryPath: directoryPath,
            folderPaths: items.filter(\.isDirectory).map(\.id),
            showHiddenFiles: showHiddenFiles
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

    private func handleDirectoryItemsInvalidatedFromDetachedPreview(_ event: DirectoryItemsInvalidatedEvent) {
        guard pathsReferToSameDirectory(event.directoryPath, path) else { return }

        let isHostWindow = event.hostWindowID == previewHostWindowID
        let pathsVisibleInList = event.invalidatedPaths.filter { invalidatedPath in
            items.contains { $0.id == invalidatedPath }
        }
        guard isHostWindow || !pathsVisibleInList.isEmpty else { return }

        let pathsToRefresh = isHostWindow ? event.invalidatedPaths : pathsVisibleInList
        selection.subtract(pathsToRefresh)
        items.removeAll { pathsToRefresh.contains($0.id) }
        loadItems(invalidatingPaths: pathsToRefresh)
    }

    private func handleRevealInHostFromDetachedPreview(_ event: PreviewRevealInHostEvent) {
        guard event.hostWindowID == previewHostWindowID else { return }
        applyExternalNavigationTarget(
            ExternalNavigationTarget(
                directoryPath: event.directoryPath,
                selectionPath: event.selectionPath
            )
        )
    }

    private func pathsReferToSameDirectory(_ lhs: String, _ rhs: String) -> Bool {
        let left = URL(fileURLWithPath: lhs).resolvingSymlinksInPath().standardizedFileURL.path
        let right = URL(fileURLWithPath: rhs).resolvingSymlinksInPath().standardizedFileURL.path
        return left == right
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
        updateGitWorkspaceFSEventsMonitoring()
    }
    
    private func updateGitWorkspaceFSEventsMonitoring(for directoryPath: String? = nil) {
        let directoryPath = directoryPath ?? path
        guard !TrashLoader.isTrashPath(directoryPath) else {
            GitWorkspaceFSEventsMonitor.shared.stop()
            return
        }
        guard let repoRoot = GitRepositoryDetector.findRepoRoot(from: directoryPath) else {
            GitWorkspaceFSEventsMonitor.shared.stop()
            return
        }
        GitWorkspaceFSEventsMonitor.shared.updateSession(repoRoot: repoRoot)
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
    
    private func openItem(_ item: FileItem, openInDetachedPreview: Bool = false) {
        if openInDetachedPreview {
            openItemInDetachedPreview(item)
            return
        }
        if item.isParentDirectoryEntry {
            navigateUp()
            return
        }

        let doubleClickAction = PreviewDoubleClickAction(rawValue: previewDoubleClickActionRaw)
            ?? .defaultValue

        switch doubleClickAction {
        case .standalonePreview:
            openItemInDetachedPreview(item)
        case .sidebarPreview:
            openItemInSidebarPreview(item)
        case .defaultApp:
            openItemWithDefaultApp(item)
        }
    }

    private func openItemWithDefaultApp(_ item: FileItem) {
        if ArchiveOperations.isArchive(item), !TrashLoader.isTrashPath(path) {
            if PreviewOpenPreferences.archiveDoubleClickAction == .preview,
               PreviewCapability.canLoadPreview(for: item) {
                openItemInDetachedPreview(item)
                return
            }
            ArchiveOperations.extract(
                archives: [item],
                mode: .here,
                navigateIntoResult: true
            ) { _ in }
            return
        }
        FileOperations.open([item]) { path = $0 }
    }

    private func revealGitPathInFileList(_ targetPath: String) {
        let standardized = (targetPath as NSString).standardizingPath
        if let item = items.first(where: {
            ($0.url.path as NSString).standardizingPath == standardized
        }) {
            selection = [item.id]
            fileListFocusToken &+= 1
            return
        }

        let parent = (standardized as NSString).deletingLastPathComponent
        guard parent != (path as NSString).standardizingPath else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }
        pendingExternalSelectionPath = standardized
        path = parent
    }

    private func openItemInSidebarPreview(_ item: FileItem) {
        if item.isDirectory {
            path = item.url.path
            selection.removeAll()
            layout.showPreview = true
            return
        }
        if ArchiveOperations.isArchive(item),
           !TrashLoader.isTrashPath(path),
           !PreviewCapability.canLoadPreview(for: item) {
            ArchiveOperations.extract(
                archives: [item],
                mode: .here,
                navigateIntoResult: true
            ) { _ in }
            return
        }
        guard PreviewCapability.canLoadPreview(for: item) else {
            FileOperations.open([item]) { path = $0 }
            return
        }
        selection = [item.id]
        layout.showPreview = true
    }

    private func openItemInDetachedPreview(_ item: FileItem) {
        if item.isParentDirectoryEntry {
            navigateUp()
            return
        }
        if item.isDirectory {
            path = item.url.path
            return
        }
        if ArchiveOperations.isArchive(item),
           !TrashLoader.isTrashPath(path),
           !PreviewCapability.canLoadPreview(for: item) {
            ArchiveOperations.extract(
                archives: [item],
                mode: .here,
                navigateIntoResult: true
            ) { _ in }
            return
        }
        guard PreviewCapability.canLoadPreview(for: item) else {
            FileOperations.open([item]) { path = $0 }
            return
        }
        ExplorerStandalonePreviewOpener.open(
            file: item,
            context: ExplorerStandalonePreviewOpener.Context(
                hostWindowID: previewHostWindowID,
                directoryPath: path,
                directoryItems: items,
                sortOrder: sortOrder,
                showHiddenFiles: showHiddenFiles,
                showPreviewPanel: layout.showPreview,
                selectionContainsFile: { selection.contains($0) },
                openWindow: openWindow,
                detachCoordinator: detachCoordinator
            )
        )
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
                FileOperations.paste(to: URL(fileURLWithPath: destPath), completion: finishPaste)
            },
            delete: deleteSelectedItems,
            canCopy: !selected.isEmpty,
            canCut: !selected.isEmpty,
            canPaste: pasteboardAvailability.canPaste(to: URL(fileURLWithPath: destPath)),
            canDelete: !deletableSelectedItems.isEmpty
        )
    }
    
    private var blankMenuActions: FileListBlankMenuActions {
        let inTrash = TrashLoader.isTrashPath(path)
        let isNetworkVolume = DirectorySizeVolumeFilter.isNetworkVolume(path: path)
        let pasteDestination = URL(fileURLWithPath: path, isDirectory: true)
        let canPaste = !inTrash && pasteboardAvailability.canPaste(to: pasteDestination)
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
                FileOperations.paste(to: pasteDestination, completion: finishPaste)
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
            open: { openItem($0) },
            openInDetachedPreview: { openItem($0, openInDetachedPreview: true) },
            canOpenInDetachedPreview: { item in
                !item.isDirectory
                    && !item.isParentDirectoryEntry
                    && PreviewCapability.canLoadPreview(for: item)
            },
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
                pasteboardAvailability.canPaste(to: URL(fileURLWithPath: destPath))
            },
            paste: { destPath in
                FileOperations.paste(to: URL(fileURLWithPath: destPath), completion: finishPaste)
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
            refresh: { loadItems() },
            compress: { items in
                ArchiveOperations.compress(
                    items: items,
                    in: URL(fileURLWithPath: path)
                ) { _ in }
            },
            extractHere: { items in
                ArchiveOperations.extract(archives: items, mode: .here) { _ in }
            },
            extractTo: { items in
                ArchiveOperations.extractToPanel(archives: items) { _ in }
            },
            extractToDownloads: { items in
                ArchiveOperations.extract(archives: items, mode: .downloads) { _ in }
            }
        )
    }

    private func handleArchiveOperationCompleted(paths: [String], navigateIntoResult: Bool = false) {
        if navigateIntoResult, let first = paths.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: first, isDirectory: &isDirectory),
               isDirectory.boolValue {
                path = first
                selection.removeAll()
                return
            }
        }
        loadItems()
        if let first = paths.first {
            selection = [first]
        }
    }
    
    private func finishPaste(_ result: FileOperations.PasteCompletion) {
        insertListingItems(at: result.destinationURLs, inlineRenamePath: result.inlineRenameURL?.path)
    }

    private func insertListingItems(at urls: [URL], inlineRenamePath: String?) {
        if let inlineRenamePath {
            pendingInlineRenamePath = inlineRenamePath
        }
        selection.removeAll()
        PasteboardPasteAvailability.shared.refreshNow()
        DirectoryFSEventsMonitor.shared.noteUserInitiatedListingRefresh()

        guard !urls.isEmpty else { return }

        let currentPath = path
        let shouldShowHiddenFiles = showHiddenFiles
        let listingOptions = DirectoryListingOptions.forPath(currentPath)
        let sort = FileListPreferencesStore.shared.sort

        Task {
            let addedItems = await Task.detached(priority: .userInitiated) {
                (try? DirectoryListingIncrementalUpdate.loadFileItems(
                    at: urls,
                    showHiddenFiles: shouldShowHiddenFiles,
                    options: listingOptions
                )) ?? []
            }.value

            await MainActor.run {
                guard !addedItems.isEmpty else {
                    loadItems()
                    return
                }
                items = DirectoryListingIncrementalUpdate.merge(
                    adding: addedItems,
                    removing: [],
                    into: items,
                    sort: sort
                )
                applyPendingInlineRenameIfNeeded(loadedItems: items, for: currentPath)
                scheduleMetadataForInsertedFolders(addedItems, in: currentPath)
            }
        }
    }

    private func createNewFolder() {
        let alert = NSAlert()
        alert.messageText = L10n.Dialog.newFolderTitle
        alert.informativeText = L10n.Dialog.newFolderMessage
        
        let textField = KeyEquivalentTextFields.plain(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
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
                    OperationRecordingHub.record(.createDirectory(url: folderURL))
                    GitWorkingTreeRefreshCenter.notifyWorkingTreeMayHaveChanged(at: folderURL.path)
                    loadItems()
                } catch {
                    let errorAlert = NSAlert(error: error)
                    errorAlert.runModal()
                }
            }
        }
    }
    
    private func createNewFile() {
        guard !TrashLoader.isTrashPath(path) else { return }

        let directoryURL = URL(fileURLWithPath: path)
        let fileURL = ArchiveOperations.uniqueNamedPath(
            name: L10n.File.defaultNewFileName,
            in: directoryURL
        )

        guard FileManager.default.createFile(atPath: fileURL.path, contents: Data()) else {
            let errorAlert = NSAlert()
            errorAlert.messageText = L10n.Dialog.cannotCreateFile
            errorAlert.informativeText = L10n.Dialog.cannotCreateFileMessage
            errorAlert.runModal()
            return
        }
        OperationRecordingHub.record(.createFile(url: fileURL))
        GitWorkingTreeRefreshCenter.notifyWorkingTreeMayHaveChanged(at: fileURL.path)
        pendingInlineRenamePath = fileURL.path
        loadItems()
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

private enum HorizontalResizeDividerMetrics {
    static let visualWidth: CGFloat = 1
    static let hitWidth: CGFloat = 6
}

private final class ResizeDividerNSView: NSView {
    var onResize: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    private var lastMouseX: CGFloat?
    private var trackingArea: NSTrackingArea?

    override var isOpaque: Bool { true }
    override var isFlipped: Bool { true }

    private var hitTestBounds: NSRect {
        bounds.insetBy(dx: -(HorizontalResizeDividerMetrics.hitWidth - bounds.width) / 2, dy: 0)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        hitTestBounds.contains(point) ? self : nil
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(hitTestBounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: hitTestBounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
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
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let thickness = PanelSeparatorStyle.hairlineThickness(for: scale)
        let lineX = floor((bounds.width - thickness) / 2)
        let lineRect = NSRect(x: lineX, y: bounds.minY, width: thickness, height: bounds.height)
        PanelSeparatorStyle.fill(dirtyRect.intersection(lineRect), in: self)
    }
}
