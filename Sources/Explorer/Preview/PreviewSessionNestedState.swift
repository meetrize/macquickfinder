import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation
import PDFKit
import SwiftUI

// MARK: - Image toolbar

@MainActor
final class PreviewSessionImageState: ObservableObject {
    @Published var zoomScale: CGFloat = 1.0
    @Published var zoomAction: ImageZoomAction?
    @Published var effectiveZoomPercent: Int = 0
    @Published var rotationQuarterTurns: Int = 0
    @Published var flipHorizontal = false
    @Published var flipVertical = false
    @Published var previewAction: ImagePreviewAction?
    @Published var eyedropperActive = false
    @Published var pickedWebColor: String?
    @Published var resizeTargetSize: CGSize?
    @Published var sourcePixelSize: CGSize = .zero
    /// 解码时使用的最长边像素上限；0 表示已全分辨率或未知。
    @Published var decodedMaxPixelSize: Int = 0
    /// 图片内容区尺寸（点），用于动态降采样预算。
    @Published var displayContainerSize: CGSize = .zero
    @Published var displayScreenScale: CGFloat = 2.0
    @Published var showResizeSheet = false
    @Published var editUndoStack: [ImageEditSnapshot] = []
    @Published var editUndoClearNonce = 0

    var hasEdits: Bool {
        rotationQuarterTurns != 0
            || flipHorizontal
            || flipVertical
            || hasResizeEdit
    }

    var hasResizeEdit: Bool {
        guard let target = resizeTargetSize else { return false }
        let oriented = effectiveOrientedPixelSize
        guard oriented.width > 0, oriented.height > 0 else { return false }
        return Int(target.width.rounded()) != Int(oriented.width.rounded())
            || Int(target.height.rounded()) != Int(oriented.height.rounded())
    }

    var effectiveOrientedPixelSize: CGSize {
        let source = sourcePixelSize
        guard source.width > 0, source.height > 0 else { return .zero }
        let turns = ((rotationQuarterTurns % 4) + 4) % 4
        if turns % 2 != 0 {
            return CGSize(width: source.height, height: source.width)
        }
        return source
    }

    var isDisplayResolutionLimited: Bool {
        guard decodedMaxPixelSize > 0 else { return false }
        let sourceMax = Int(max(sourcePixelSize.width, sourcePixelSize.height).rounded())
        guard sourceMax > 0 else { return false }
        return decodedMaxPixelSize < sourceMax
    }

    var resizeDialogSize: (width: Int, height: Int) {
        let oriented = effectiveOrientedPixelSize
        if let target = resizeTargetSize {
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

    func resetToolbar() {
        zoomScale = 1.0
        zoomAction = nil
        effectiveZoomPercent = 0
        rotationQuarterTurns = 0
        flipHorizontal = false
        flipVertical = false
        previewAction = nil
        eyedropperActive = false
        pickedWebColor = nil
        resizeTargetSize = nil
        sourcePixelSize = .zero
        decodedMaxPixelSize = 0
        editUndoStack.removeAll()
    }

    func prepareForLoad() {
        zoomScale = 1.0
        zoomAction = nil
        effectiveZoomPercent = 0
        rotationQuarterTurns = 0
        flipHorizontal = false
        flipVertical = false
        previewAction = nil
        eyedropperActive = false
        pickedWebColor = nil
        resizeTargetSize = nil
        decodedMaxPixelSize = 0
        displayContainerSize = .zero
    }

    func resetViewTransform() {
        performEdit {
            zoomScale = 1.0
            zoomAction = .fit
            rotationQuarterTurns = 0
            flipHorizontal = false
            flipVertical = false
            resizeTargetSize = nil
        }
    }

    func pushEditUndoSnapshot() {
        editUndoStack.append(
            ImageEditSnapshot(
                rotationQuarterTurns: rotationQuarterTurns,
                flipHorizontal: flipHorizontal,
                flipVertical: flipVertical,
                resizeTargetSize: resizeTargetSize,
                zoomScale: zoomScale
            )
        )
        if editUndoStack.count > 100 {
            editUndoStack.removeFirst(editUndoStack.count - 100)
        }
    }

    func performEdit(_ action: () -> Void) {
        pushEditUndoSnapshot()
        action()
    }

    func undoLastEdit() {
        guard let snapshot = editUndoStack.popLast() else { return }
        rotationQuarterTurns = snapshot.rotationQuarterTurns
        flipHorizontal = snapshot.flipHorizontal
        flipVertical = snapshot.flipVertical
        resizeTargetSize = snapshot.resizeTargetSize
        zoomScale = snapshot.zoomScale
    }

    func clearEditUndoStack() {
        editUndoStack.removeAll()
    }
}

// MARK: - PDF toolbar

@MainActor
final class PreviewSessionPDFState: ObservableObject {
    @Published var currentPage = 0
    @Published var pageCount = 0
    @Published var scalePercent = 0
    @Published var navigateAction: PDFNavigationAction?
    @Published var pageInput = ""

    func resetToolbar() {
        currentPage = 0
        pageCount = 0
        scalePercent = 0
        navigateAction = nil
        pageInput = ""
    }
}

// MARK: - Text / Markdown / HTML toolbar

@MainActor
final class PreviewSessionTextState: ObservableObject {
    @Published var wrapEnabled = false
    @Published var previewAction: TextPreviewAction?
    @Published var searchQuery = ""
    @Published var searchNextToken: UInt = 0
    @Published var searchMatchCount = 0
    @Published var markdownMode: MarkdownDisplayMode = .preview
    @Published var markdownPreviewScale: CGFloat = 1.0
    @Published var markdownSourceFontSize: CGFloat = 13
    @Published var htmlMode: HtmlDisplayMode = .preview

    func resetToolbar() {
        wrapEnabled = false
        previewAction = nil
        searchQuery = ""
        searchNextToken = 0
        searchMatchCount = 0
        markdownMode = .preview
        markdownPreviewScale = 1.0
        markdownSourceFontSize = 13
        htmlMode = .preview
    }

    func findNextSearchMatch() {
        searchNextToken &+= 1
    }
}

// MARK: - Media toolbar

@MainActor
final class PreviewSessionMediaState: ObservableObject {
    @Published var controlAction: MediaControlAction?
    @Published var isPlaying = false
    @Published var isMuted = false

    func resetToolbar() {
        controlAction = nil
        isPlaying = false
        isMuted = false
    }
}

// MARK: - Office toolbar

@MainActor
final class PreviewSessionOfficeState: ObservableObject {
    @Published var reloadToken = 0
    @Published var zoomScale: CGFloat = 1.0
    @Published var currentPage = 0
    @Published var pageCount = 0
    @Published var navigateAction: OfficePreviewNavigateAction?
    @Published var navigateRevision: UInt = 0
    @Published var panMode = false
    @Published var spreadsheetMode: SpreadsheetDisplayMode = .text
    @Published var wordDocumentMode: WordDocumentDisplayMode = .text

    func resetToolbar() {
        reloadToken = 0
        zoomScale = 1.0
        currentPage = 0
        pageCount = 0
        navigateAction = nil
        navigateRevision = 0
        panMode = false
        spreadsheetMode = .text
        wordDocumentMode = .text
    }

    func sendNavigate(_ action: OfficePreviewNavigateAction) {
        navigateAction = action
        navigateRevision &+= 1
    }
}

// MARK: - Archive toolbar

@MainActor
final class PreviewSessionArchiveState: ObservableObject {
    @Published var reloadToken = 0
    @Published var copyAction: ArchivePreviewAction?
    @Published var extractAction: ArchivePreviewAction?
    @Published var selectedEntryPaths: Set<String> = []
    @Published var expandedDirectoryPaths: Set<String> = []
    @Published var isLoadingMore = false
    var listingGeneration = 0

    func resetToolbar() {
        reloadToken = 0
        copyAction = nil
        extractAction = nil
        selectedEntryPaths = []
        expandedDirectoryPaths = []
        isLoadingMore = false
        listingGeneration = 0
    }

    func prepareForLoad() {
        copyAction = nil
        extractAction = nil
        selectedEntryPaths = []
        expandedDirectoryPaths = []
        isLoadingMore = false
        listingGeneration &+= 1
    }
}

// MARK: - Loaded content

@MainActor
final class PreviewSessionContentState: ObservableObject {
    @Published var loadPhase: PreviewLoadPhase = .idle
    @Published var textContent = ""
    @Published var image: NSImage?
    @Published var pdfDocument: PDFDocument?
    @Published var mediaPlayer: AVPlayer?
    @Published var officeURL: URL?
    @Published var officeRichText: NSAttributedString?
    @Published var archiveEntries: [ArchiveEntryPreview] = []
    @Published var archiveTruncated = false
    @Published var imageSaveErrorMessage: String?

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

    func clear() {
        textContent = ""
        image = nil
        pdfDocument = nil
        mediaPlayer?.pause()
        mediaPlayer = nil
        officeURL = nil
        officeRichText = nil
        archiveEntries = []
        archiveTruncated = false
    }
}

// MARK: - Child observation

extension PreviewSession {
    func observeNestedState<T: ObservableObject>(_ child: T, storage: inout Set<AnyCancellable>) {
        child.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &storage)
    }
}
