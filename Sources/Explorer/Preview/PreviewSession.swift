import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation
import PDFKit

/// 单个文件预览会话：按类型分组的嵌套状态 + 浏览上下文。
@MainActor
final class PreviewSession: ObservableObject, Identifiable {
    let id: PreviewSessionID
    let hostWindowID: UUID
    let file: FileItem

    @Published var location: PreviewSessionLocation = .inline
    @Published var folderInlineChild: FileItem?

    var image = PreviewSessionImageState()
    var pdf = PreviewSessionPDFState()
    var text = PreviewSessionTextState()
    var media = PreviewSessionMediaState()
    var office = PreviewSessionOfficeState()
    var archive = PreviewSessionArchiveState()
    var content = PreviewSessionContentState()

    /// 独立窗口内目录浏览上下文；弹出时附加，收回时清除。
    @Published var browseContext: PreviewBrowserContext?
    /// 独立窗口底部胶片条是否展开（弹出时默认展开，收回侧栏后重置）。
    @Published var isBrowserStripExpanded = false

    var loadTask: Task<Void, Never>?
    private var browseContextCancellable: AnyCancellable?
    private var nestedStateCancellables = Set<AnyCancellable>()
    let browseContentPrefetcher = PreviewBrowserContentPrefetcher()

    var isLoading: Bool { content.isLoading }
    var errorMessage: String? { content.errorMessage }
    var isImagePreview: Bool { content.isImagePreview }

    init(
        id: PreviewSessionID = PreviewSessionID(),
        hostWindowID: UUID,
        file: FileItem,
        folderInlineChild: FileItem? = nil
    ) {
        self.id = id
        self.hostWindowID = hostWindowID
        self.file = file
        self.folderInlineChild = folderInlineChild
        observeNestedStates()
    }

    private func observeNestedStates() {
        observeNestedState(image, storage: &nestedStateCancellables)
        observeNestedState(pdf, storage: &nestedStateCancellables)
        observeNestedState(text, storage: &nestedStateCancellables)
        observeNestedState(media, storage: &nestedStateCancellables)
        observeNestedState(office, storage: &nestedStateCancellables)
        observeNestedState(archive, storage: &nestedStateCancellables)
        observeNestedState(content, storage: &nestedStateCancellables)
    }

    var previewContentItem: FileItem? {
        folderInlineChild ?? file
    }

    /// 当前应加载/展示的文件：浏览模式下为 context 当前项，否则为侧栏预览项。
    var browseTarget: FileItem {
        if let browseContext {
            return browseContext.currentItem
        }
        return previewContentItem ?? file
    }

    var isShowingFolderChildPreview: Bool {
        folderInlineChild != nil
    }

    var toolbarFileItem: FileItem? {
        let item = browseTarget
        guard !item.isDirectory else { return nil }
        return item
    }

    /// 切换预览文件或文件夹内联子项时重置工具栏控件。
    func resetControls() {
        PreviewSessionStateReset.resetAllToolbarControls(on: self)
    }

    func cancelLoad() {
        let hadActiveTask = loadTask != nil
        loadTask?.cancel()
        loadTask = nil
        content.mediaPlayer?.pause()
        if hadActiveTask, case .loading = content.loadPhase {
            content.loadPhase = .idle
        }
    }

    func attachBrowserContext(_ context: PreviewBrowserContext) {
        browseContextCancellable?.cancel()
        browseContext = context
        browseContextCancellable = context.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
        scheduleBrowseContentPrefetch()
    }

    func clearBrowserContext() {
        browseContextCancellable?.cancel()
        browseContextCancellable = nil
        browseContext = nil
        isBrowserStripExpanded = false
        browseContentPrefetcher.cancel()
    }

    func scheduleBrowseContentPrefetch() {
        guard let browseContext else { return }
        guard !DirectorySizeVolumeFilter.isNetworkVolume(path: browseContext.directoryPath) else {
            browseContentPrefetcher.cancel()
            return
        }
        browseContentPrefetcher.schedulePrefetch(
            items: browseContext.orderedItems,
            centerIndex: browseContext.currentIndex
        )
    }

    @discardableResult
    func switchBrowseTarget(to item: FileItem) -> Bool {
        guard let browseContext else { return false }
        guard let index = browseContext.orderedItems.firstIndex(where: { $0.id == item.id }) else { return false }
        guard browseContext.currentIndex != index else { return false }
        browseContext.select(index: index)
        return true
    }

    @discardableResult
    func browsePrevious() -> Bool {
        browseContext?.selectPrevious() ?? false
    }

    @discardableResult
    func browseNext() -> Bool {
        browseContext?.selectNext() ?? false
    }

    deinit {
        browseContextCancellable?.cancel()
        loadTask?.cancel()
    }
}
