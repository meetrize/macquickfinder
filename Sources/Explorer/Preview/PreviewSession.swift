import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation
import PDFKit

/// 单个文件预览会话：工具栏状态、文件夹内联子项与（PD-03 起）加载结果。
@MainActor
final class PreviewSession: ObservableObject, Identifiable {
    let id: PreviewSessionID
    let hostWindowID: UUID
    let file: FileItem

    @Published var location: PreviewSessionLocation = .inline
    @Published var folderInlineChild: FileItem?

    // MARK: - Image toolbar / view state

    @Published var imageZoomScale: CGFloat = 1.0
    @Published var imageZoomAction: ImageZoomAction?
    @Published var imageEffectiveZoomPercent: Int = 0
    @Published var imageRotationQuarterTurns: Int = 0
    @Published var imageFlipHorizontal = false
    @Published var imageFlipVertical = false
    @Published var imagePreviewAction: ImagePreviewAction?
    @Published var imageEyedropperActive = false
    @Published var imagePickedWebColor: String?
    @Published var imageResizeTargetSize: CGSize?
    @Published var imageSourcePixelSize: CGSize = .zero
    @Published var showImageResizeSheet = false
    @Published var imageEditUndoStack: [ImageEditSnapshot] = []
    @Published var imageEditUndoClearNonce = 0

    // MARK: - PDF toolbar state

    @Published var pdfCurrentPage = 0
    @Published var pdfPageCount = 0
    @Published var pdfScalePercent = 0
    @Published var pdfNavigateAction: PDFNavigationAction?
    @Published var pdfPageInput = ""

    // MARK: - Text / Markdown / HTML toolbar state

    @Published var textWrapEnabled = true
    @Published var textPreviewAction: TextPreviewAction?
    @Published var markdownMode: MarkdownDisplayMode = .preview
    @Published var markdownPreviewScale: CGFloat = 1.0
    @Published var markdownSourceFontSize: CGFloat = 13
    @Published var htmlMode: HtmlDisplayMode = .preview

    // MARK: - Media toolbar state

    @Published var mediaControlAction: MediaControlAction?
    @Published var mediaIsPlaying = false
    @Published var mediaIsMuted = false

    // MARK: - Office toolbar state

    @Published var officeReloadToken = 0
    @Published var officeScalePercent = 0
    @Published var officeNavigateAction: OfficeNavigationAction?

    // MARK: - Archive toolbar state

    @Published var archiveExpanded = true
    @Published var archiveReloadToken = 0
    @Published var archiveCopyAction: ArchivePreviewAction?

    /// 独立窗口内目录浏览上下文；弹出时附加，收回时清除。
    @Published var browseContext: PreviewBrowserContext?
    /// 独立窗口底部胶片条是否展开（默认收起）。
    @Published var isBrowserStripExpanded = false

    // MARK: - Loaded content

    @Published var loadPhase: PreviewLoadPhase = .idle
    @Published var textContent = ""
    @Published var image: NSImage?
    @Published var pdfDocument: PDFDocument?
    @Published var mediaPlayer: AVPlayer?
    @Published var officeURL: URL?
    @Published var archiveEntries: [ArchiveEntryPreview] = []
    @Published var archiveTruncated = false
    @Published var imageSaveErrorMessage: String?

    var loadTask: Task<Void, Never>?
    private var browseContextCancellable: AnyCancellable?
    let browseContentPrefetcher = PreviewBrowserContentPrefetcher()

    var isLoading: Bool {
        if case .loading = loadPhase { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message) = loadPhase { return message }
        return nil
    }

    var isImagePreview: Bool {
        image != nil && !isLoading && errorMessage == nil
    }

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

    var hasImageEdits: Bool {
        imageRotationQuarterTurns != 0
            || imageFlipHorizontal
            || imageFlipVertical
            || hasImageResizeEdit
    }

    var hasImageResizeEdit: Bool {
        guard let target = imageResizeTargetSize else { return false }
        let oriented = imageEffectiveOrientedPixelSize
        guard oriented.width > 0, oriented.height > 0 else { return false }
        return Int(target.width.rounded()) != Int(oriented.width.rounded())
            || Int(target.height.rounded()) != Int(oriented.height.rounded())
    }

    var imageEffectiveOrientedPixelSize: CGSize {
        let source = imageSourcePixelSize
        guard source.width > 0, source.height > 0 else { return .zero }
        let turns = ((imageRotationQuarterTurns % 4) + 4) % 4
        if turns % 2 != 0 {
            return CGSize(width: source.height, height: source.width)
        }
        return source
    }

    var imageResizeDialogSize: (width: Int, height: Int) {
        let oriented = imageEffectiveOrientedPixelSize
        if let target = imageResizeTargetSize {
            return (
                max(1, Int(target.width.rounded())),
                max(1, Int(target.height.rounded()))
            )
        }
        return (
            max(1, Int(oriented.width.rounded())),
            max(1, Int(oriented.height.rounded()))
        )
    }

    /// 切换预览文件或文件夹内联子项时重置工具栏控件（等价 `FilePreviewView.resetPreviewControls()`）。
    func resetControls() {
        imageZoomScale = 1.0
        imageZoomAction = nil
        imageEffectiveZoomPercent = 0
        imageRotationQuarterTurns = 0
        imageFlipHorizontal = false
        imageFlipVertical = false
        imagePreviewAction = nil
        imageEyedropperActive = false
        imagePickedWebColor = nil
        imageResizeTargetSize = nil
        imageSourcePixelSize = .zero
        imageEditUndoStack.removeAll()
        textWrapEnabled = true
        textPreviewAction = nil
        mediaControlAction = nil
        mediaIsPlaying = false
        mediaIsMuted = false
        officeReloadToken = 0
        officeScalePercent = 0
        officeNavigateAction = nil
        archiveExpanded = true
        archiveReloadToken = 0
        archiveCopyAction = nil
        pdfCurrentPage = 0
        pdfPageCount = 0
        pdfScalePercent = 0
        pdfNavigateAction = nil
        pdfPageInput = ""
        markdownMode = .preview
        markdownPreviewScale = 1.0
        markdownSourceFontSize = 13
        htmlMode = .preview
    }

    func resetImageViewTransform() {
        performImageEdit {
            imageZoomScale = 1.0
            imageZoomAction = .fit
            imageRotationQuarterTurns = 0
            imageFlipHorizontal = false
            imageFlipVertical = false
            imageResizeTargetSize = nil
        }
    }

    func pushImageEditUndoSnapshot() {
        imageEditUndoStack.append(
            ImageEditSnapshot(
                rotationQuarterTurns: imageRotationQuarterTurns,
                flipHorizontal: imageFlipHorizontal,
                flipVertical: imageFlipVertical,
                resizeTargetSize: imageResizeTargetSize,
                zoomScale: imageZoomScale
            )
        )
        if imageEditUndoStack.count > 100 {
            imageEditUndoStack.removeFirst(imageEditUndoStack.count - 100)
        }
    }

    func performImageEdit(_ action: () -> Void) {
        pushImageEditUndoSnapshot()
        action()
    }

    func undoLastImageEdit() {
        guard let snapshot = imageEditUndoStack.popLast() else { return }
        imageRotationQuarterTurns = snapshot.rotationQuarterTurns
        imageFlipHorizontal = snapshot.flipHorizontal
        imageFlipVertical = snapshot.flipVertical
        imageResizeTargetSize = snapshot.resizeTargetSize
        imageZoomScale = snapshot.zoomScale
    }

    func clearImageEditUndoStack() {
        imageEditUndoStack.removeAll()
    }

    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
        mediaPlayer?.pause()
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
