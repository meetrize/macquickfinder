import Foundation
import FileList

/// 单栏浏览状态（路径 / 列表 / 选中 / 历史）。主栏仍可由 ContentView @State 承载；副栏用本类型。
@MainActor
final class ExplorerPaneState: ObservableObject {
    let id: ExplorerPaneID

    @Published var path: String
    @Published var items: [FileItem] = []
    @Published var selection: Set<FileItem.ID> = []
    @Published var isLoading = false
    @Published var quickSearchText = ""
    @Published var isQuickSearchVisible = false
    @Published var isPathBarTextMode = false
    @Published var activeBarField: BarTextFieldID?
    @Published var fileListFocusToken: UInt = 0
    @Published var isFileListRenaming = false

    var pathNavigation = PathNavigationHistory()
    private(set) var loadGeneration: UInt = 0
    private var isApplyingHistoryNavigation = false
    private var lastRecordedPath: String?

    init(id: ExplorerPaneID, path: String) {
        self.id = id
        self.path = path
        self.lastRecordedPath = path
    }

    var canNavigateBack: Bool { pathNavigation.canGoBack }
    var canNavigateForward: Bool { pathNavigation.canGoForward }

    var selectedItems: [FileItem] {
        FileItem.resolveSelection(ids: selection, from: items)
    }

    var hasRealSelection: Bool {
        selection.contains { id in
            items.first(where: { $0.id == id })?.isParentDirectoryEntry == false
        }
    }

    /// 仅更新路径与历史；调用方需接着 `loadItems(showHiddenFiles:)`。
    func navigateToDirectory(_ targetPath: String) {
        selection.removeAll()
        if path != targetPath {
            recordNavigationIfNeeded(to: targetPath)
            path = targetPath
        }
    }

    @discardableResult
    func navigateBack() -> Bool {
        guard let previous = pathNavigation.goBack(from: path) else { return false }
        isApplyingHistoryNavigation = true
        path = previous
        selection.removeAll()
        lastRecordedPath = previous
        isApplyingHistoryNavigation = false
        return true
    }

    @discardableResult
    func navigateForward() -> Bool {
        guard let next = pathNavigation.goForward(from: path) else { return false }
        isApplyingHistoryNavigation = true
        path = next
        selection.removeAll()
        lastRecordedPath = next
        isApplyingHistoryNavigation = false
        return true
    }

    func navigateToHistoryPath(_ target: String) {
        pathNavigation.jump(to: target, from: path)
        isApplyingHistoryNavigation = true
        path = target
        selection.removeAll()
        lastRecordedPath = target
        isApplyingHistoryNavigation = false
    }

    func applyExternalNavigationTarget(_ target: ExternalNavigationTarget) {
        _ = target.selectionPath
        navigateToDirectory(target.directoryPath)
    }

    func recordNavigationIfNeeded(to newPath: String) {
        guard !isApplyingHistoryNavigation else { return }
        let old = lastRecordedPath ?? path
        pathNavigation.recordNavigation(from: old, to: newPath)
        lastRecordedPath = newPath
    }

    func loadItems(
        showHiddenFiles: Bool,
        clearingSelection: Bool = true,
        showsLoadingIndicator: Bool = true
    ) {
        loadGeneration &+= 1
        let currentGeneration = loadGeneration
        let currentPath = path
        let shouldPreserveSelection = !items.isEmpty && !clearingSelection
        let preservedSelection = shouldPreserveSelection ? selection : []
        let listingOptions = DirectoryListingOptions.forPath(currentPath)

        if showsLoadingIndicator || items.isEmpty {
            isLoading = true
        }
        if clearingSelection {
            selection.removeAll()
        }

        Task {
            var loadedItems: [FileItem] = []
            do {
                if TrashLoader.isTrashPath(currentPath) {
                    loadedItems = await TrashLoader.loadItems(showHiddenFiles: showHiddenFiles)
                } else {
                    loadedItems = try await Task.detached(priority: .userInitiated) {
                        try DirectoryListingLoader.loadFileItems(
                            at: currentPath,
                            showHiddenFiles: showHiddenFiles,
                            options: listingOptions,
                            onEachURL: { _ in try Task.checkCancellation() }
                        )
                    }.value
                }
            } catch is CancellationError {
                return
            } catch {
                print("ExplorerPaneState load error: \(error)")
            }

            guard !Task.isCancelled, currentGeneration == loadGeneration else { return }

            await MainActor.run {
                guard currentGeneration == self.loadGeneration else { return }
                self.items = loadedItems
                self.isLoading = false
                self.fileListFocusToken &+= 1
                if shouldPreserveSelection {
                    self.selection = ListingSelectionRestorer.restoredIDs(
                        preserved: preservedSelection,
                        loadedItems: loadedItems
                    )
                }
            }
        }
    }

    /// 退出双栏时释放副栏占用：取消 in-flight load，清空列表。
    func releaseResources() {
        loadGeneration &+= 1
        items = []
        selection.removeAll()
        isLoading = false
        quickSearchText = ""
        isQuickSearchVisible = false
        isPathBarTextMode = false
        activeBarField = nil
        isFileListRenaming = false
        pathNavigation = PathNavigationHistory()
        lastRecordedPath = path
    }

    func adoptSnapshot(path: String, items: [FileItem], selection: Set<FileItem.ID>) {
        loadGeneration &+= 1
        self.path = path
        self.items = items
        self.selection = selection
        self.isLoading = false
        self.lastRecordedPath = path
        self.fileListFocusToken &+= 1
    }
}
