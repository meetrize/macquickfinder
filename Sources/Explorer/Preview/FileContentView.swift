import SwiftUI
import AppKit
import FileList

struct FileContentView: View {
    @ObservedObject var session: PreviewSession
    @ObservedObject private var customPreviewStore = CustomPreviewRuleStore.shared
    @ObservedObject private var shortcutSettings = ShortcutSettingsStore.shared
    @AppStorage(AppPreferences.Preview.codeShowLineNumbers)
    private var codePreviewShowLineNumbers = false
    @State private var lastAppliedLoadTaskID: String?
    @State private var contentOpacity: Double = 1
    @State private var previewTextSelectionActive = false

    private var item: FileItem {
        session.browseTarget
    }

    private var fileExtension: String {
        item.url.pathExtension.lowercased()
    }

    private var isHtmlPreviewMode: Bool {
        PreviewTypeClassifier.isHtmlFile(fileExtension) && session.text.htmlMode == .preview
    }

    private var usesMarkdownPreview: Bool {
        PreviewTypeClassifier.isMarkdownFile(fileExtension) && session.text.markdownMode == .preview
    }

    private var usesSpreadsheetQuickLook: Bool {
        PreviewTypeClassifier.isSpreadsheetFile(fileExtension)
            && session.office.spreadsheetMode == .quickLook
    }

    private var isSpreadsheetTextMode: Bool {
        PreviewTypeClassifier.isSpreadsheetFile(fileExtension)
            && session.office.spreadsheetMode == .text
            && !session.content.textContent.isEmpty
    }

    private var usesWordDocumentFormattedMode: Bool {
        PreviewTypeClassifier.isWordDocumentFile(fileExtension)
            && session.office.wordDocumentMode == .formatted
    }

    private var isWordDocumentTextMode: Bool {
        PreviewTypeClassifier.isWordDocumentFile(fileExtension)
            && session.office.wordDocumentMode == .text
            && !session.content.textContent.isEmpty
    }

    private var spreadsheetQuickLookURL: URL {
        session.content.officeURL ?? item.url
    }

    private var showsCodeLineNumbers: Bool {
        codePreviewShowLineNumbers && PreviewTypeClassifier.isCodeFile(fileExtension)
    }

    private var canEnterPreviewTextEdit: Bool {
        guard !session.text.isEditing else { return false }
        guard session.content.loadPhase == .loaded else { return false }
        return PreviewTextEditEligibility.canOfferEdit(file: session.browseTarget, session: session)
    }

    private var imageResizePreviewIdentity: String {
        guard let size = session.image.resizeTargetSize else { return "image-original-size" }
        return "image-resize-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    private var contentLoadTaskID: String {
        "\(session.browseTarget.id)-\(session.archive.reloadToken)-\(Int(customPreviewStore.revision))"
    }

    private var imageDisplayMetricsToken: String {
        let size = session.image.displayContainerSize
        guard size.width > 0, size.height > 0 else { return "image-metrics-pending" }
        return "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))-\(session.currentImagePreviewPixelBudget())"
    }

    private var prefersTextContentInsets: Bool {
        if session.content.image != nil { return false }
        if session.content.pdfDocument != nil { return false }
        if session.content.mediaPlayer != nil { return false }
        if usesSpreadsheetQuickLook { return false }
        if session.content.officeURL != nil, !isSpreadsheetTextMode, !isWordDocumentTextMode { return false }
        if !session.content.archiveEntries.isEmpty { return false }
        if PreviewTypeClassifier.isCodeFile(fileExtension) { return false }

        if usesWordDocumentFormattedMode, session.content.officeRichText != nil { return true }
        if session.content.epubPackage != nil { return true }
        if session.content.emlContent != nil { return true }
        if session.content.fontContent != nil { return true }
        if session.content.model3DContent != nil { return false }
        if isHtmlPreviewMode { return true }
        if PreviewTextEditEligibility.showsTextPreviewContent(file: session.browseTarget, session: session) {
            return true
        }

        if session.isLoading || session.errorMessage != nil {
            return inferredTextKindForInsets
        }
        return false
    }

    private var inferredTextKindForInsets: Bool {
        if PreviewTypeClassifier.isCodeFile(fileExtension) { return false }
        if PreviewTypeClassifier.isSpreadsheetFile(fileExtension) {
            return session.office.spreadsheetMode == .text
        }
        if PreviewTypeClassifier.isWordDocumentFile(fileExtension) {
            return true
        }
        return PreviewDetachedWindowContentKind.from(file: session.browseTarget) == .text
    }

    private var effectiveTextContentInsets: CGFloat {
        prefersTextContentInsets
            ? DetachedPreviewWindowLayoutMetrics.textContentInsets
            : 0
    }

    var body: some View {
        ZStack {
            if session.isLoading {
                ProgressView(L10n.Preview.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMsg = session.errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text(L10n.Preview.errorLoading)
                        .font(.headline)

                    Text(errorMsg)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    PreviewModeActionsRow(
                        onSelect: { mode in
                            customPreviewStore.upsertRule(forExtension: fileExtension, mode: mode)
                        },
                        onOpenSettings: {
                            openPreviewSettings(prefillExtension: fileExtension)
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let image = session.content.image {
                ImagePreviewContent(
                    image: image,
                    fileURL: item.url,
                    zoomScale: $session.image.zoomScale,
                    zoomAction: $session.image.zoomAction,
                    effectiveZoomPercent: $session.image.effectiveZoomPercent,
                    rotationQuarterTurns: $session.image.rotationQuarterTurns,
                    flipHorizontal: $session.image.flipHorizontal,
                    flipVertical: $session.image.flipVertical,
                    resizeTargetSize: $session.image.resizeTargetSize,
                    eyedropperActive: $session.image.eyedropperActive,
                    pickedWebColor: $session.image.pickedWebColor,
                    isCropping: $session.image.isCropping,
                    cropDraftNormalized: $session.image.cropDraftNormalized,
                    cropRectNormalized: $session.image.cropRectNormalized
                )
                .id(imageResizePreviewIdentity)
            } else if let pdfDoc = session.content.pdfDocument {
                PDFPreview(
                    document: pdfDoc,
                    navigationAction: $session.pdf.navigateAction,
                    previewTextSelectionActive: $previewTextSelectionActive,
                    searchQuery: $session.text.searchQuery,
                    searchNextToken: $session.text.searchNextToken,
                    searchPrevToken: $session.text.searchPrevToken,
                    searchMatchCount: $session.text.searchMatchCount,
                    searchCurrentIndex: $session.text.searchCurrentIndex
                ) { currentPage, pageCount, scalePercent in
                    session.pdf.currentPage = currentPage
                    session.pdf.pageCount = pageCount
                    session.pdf.scalePercent = scalePercent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let player = session.content.mediaPlayer {
                MediaPreview(
                    player: player,
                    controlAction: $session.media.controlAction
                ) { isPlaying, isMuted in
                    session.media.isPlaying = isPlaying
                    session.media.isMuted = isMuted
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if usesWordDocumentFormattedMode, let officeRichText = session.content.officeRichText {
                OfficeRichTextPreview(
                    attributedText: officeRichText,
                    wrapLines: session.text.wrapEnabled,
                    textContentInset: effectiveTextContentInsets,
                    zoomScale: session.office.zoomScale,
                    previewTextSelectionActive: $previewTextSelectionActive,
                    searchQuery: $session.text.searchQuery,
                    searchNextToken: $session.text.searchNextToken,
                    searchPrevToken: $session.text.searchPrevToken,
                    searchMatchCount: $session.text.searchMatchCount,
                    searchCurrentIndex: $session.text.searchCurrentIndex
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if usesSpreadsheetQuickLook {
                QuickLookPreview(
                    url: spreadsheetQuickLookURL,
                    reloadToken: session.office.reloadToken,
                    navigateRevision: session.office.navigateRevision,
                    navigateAction: session.office.navigateAction,
                    onStateChanged: { currentPage, pageCount, zoomScale in
                        if session.office.currentPage != currentPage {
                            session.office.currentPage = currentPage
                        }
                        if session.office.pageCount != pageCount {
                            session.office.pageCount = pageCount
                        }
                        if abs(session.office.zoomScale - zoomScale) > 0.001 {
                            session.office.zoomScale = zoomScale
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let officeURL = session.content.officeURL, !isSpreadsheetTextMode, !isWordDocumentTextMode {
                QuickLookPreview(
                    url: officeURL,
                    reloadToken: session.office.reloadToken,
                    navigateRevision: session.office.navigateRevision,
                    navigateAction: session.office.navigateAction,
                    onStateChanged: { currentPage, pageCount, zoomScale in
                        if session.office.currentPage != currentPage {
                            session.office.currentPage = currentPage
                        }
                        if session.office.pageCount != pageCount {
                            session.office.pageCount = pageCount
                        }
                        if abs(session.office.zoomScale - zoomScale) > 0.001 {
                            session.office.zoomScale = zoomScale
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !session.content.archiveEntries.isEmpty {
                ArchiveListPreview(
                    entries: session.content.archiveEntries,
                    truncated: session.content.archiveTruncated,
                    isLoadingMore: session.archive.isLoadingMore,
                    expandedDirectoryPaths: $session.archive.expandedDirectoryPaths,
                    selectedEntryPaths: $session.archive.selectedEntryPaths,
                    copyAction: $session.archive.copyAction
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onChange(of: session.archive.reloadToken) { _ in
                    session.archive.selectedEntryPaths = []
                }
            } else if let epubPackage = session.content.epubPackage {
                EpubPreviewView(
                    session: session,
                    package: epubPackage,
                    textContentInset: effectiveTextContentInsets
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let emlContent = session.content.emlContent {
                EmlPreviewView(
                    content: emlContent,
                    textContentInset: effectiveTextContentInsets
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let fontContent = session.content.fontContent {
                FontPreviewView(
                    content: fontContent,
                    textContentInset: effectiveTextContentInsets
                )
                .id(fontContent.sourcePath)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let model3DContent = session.content.model3DContent {
                Model3DPreviewView(session: session, content: model3DContent)
                    .id(model3DContent.sourcePath)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isHtmlPreviewMode {
                HTMLFilePreview(fileURL: item.url, textContentInset: effectiveTextContentInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if PreviewTextEditEligibility.showsTextPreviewContent(file: item, session: session) {
                if usesMarkdownPreview {
                    MarkdownFilePreview(
                        markdown: session.content.textContent,
                        wrapLines: session.text.wrapEnabled,
                        textContentInset: effectiveTextContentInsets,
                        zoomScale: $session.text.markdownPreviewScale,
                        previewTextSelectionActive: $previewTextSelectionActive,
                        searchQuery: $session.text.searchQuery,
                        searchNextToken: $session.text.searchNextToken,
                        searchPrevToken: $session.text.searchPrevToken,
                        searchMatchCount: $session.text.searchMatchCount,
                        searchCurrentIndex: $session.text.searchCurrentIndex
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextFilePreview(
                        text: session.content.textContent,
                        fileExtension: fileExtension,
                        wrapLines: session.text.wrapEnabled,
                        fontSize: PreviewTypeClassifier.isMarkdownFile(fileExtension) ? session.text.markdownSourceFontSize : NSFont.systemFontSize,
                        showLineNumbers: showsCodeLineNumbers,
                        textContentInset: effectiveTextContentInsets,
                        displayMode: $session.text.displayMode,
                        onLiveContentChange: { session.updateTextEditDirtyState(with: $0) },
                        previewTextSelectionActive: $previewTextSelectionActive,
                        action: $session.text.previewAction,
                        searchQuery: $session.text.searchQuery,
                        searchNextToken: $session.text.searchNextToken,
                        searchPrevToken: $session.text.searchPrevToken,
                        searchMatchCount: $session.text.searchMatchCount,
                        searchCurrentIndex: $session.text.searchCurrentIndex,
                        contentSearchJumpLine: $session.text.contentSearchJumpLine,
                        contentSearchJumpToken: $session.text.contentSearchJumpToken
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if !session.isLoading, session.errorMessage == nil {
                CustomPreviewUnavailableView(
                    fileExtension: fileExtension,
                    onAddRule: { mode in
                        customPreviewStore.upsertRule(forExtension: fileExtension, mode: mode)
                    },
                    onOpenSettings: {
                        openPreviewSettings(prefillExtension: fileExtension)
                    }
                )
            } else {
                Text(L10n.Preview.notAvailable)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .opacity(contentOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PreviewImageDisplaySizeReporter(session: session))
        .focusedValue(\.previewTextSelectionActive, previewTextSelectionActive)
        .focusedValue(\.previewTextEditActive, session.text.isEditing && previewTextSelectionActive)
        .focusedValue(\.previewTextEditSave, session.text.isEditing ? {
            Task { await session.saveEditedText() }
        } : nil)
        .background(TextEditingKeyMonitor(isActive: previewTextSelectionActive))
        .background {
            LocalShortcutMonitor(
                binding: shortcutSettings.previewTextEditBinding,
                isEnabled: canEnterPreviewTextEdit
            ) {
                session.enterTextEditMode()
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .task(id: contentLoadTaskID) {
            await applyLoadTaskIfNeeded()
        }
        .onChange(of: imageDisplayMetricsToken) { _ in
            guard PreviewTypeClassifier.isImageFile(fileExtension) else { return }
            session.scheduleImagePreviewResolutionUpgradeIfNeeded()
        }
        .onChange(of: session.browseTarget.id) { _ in
            previewTextSelectionActive = false
            guard session.browseContext != nil else { return }
            contentOpacity = 0.35
            withAnimation(.easeInOut(duration: PreviewBrowserStripMetrics.contentCrossfadeDuration)) {
                contentOpacity = 1
            }
        }
        .onChange(of: session.text.markdownMode) { _ in
            previewTextSelectionActive = false
        }
        .onChange(of: session.office.spreadsheetMode) { _ in
            previewTextSelectionActive = false
        }
        .onChange(of: session.office.wordDocumentMode) { _ in
            previewTextSelectionActive = false
        }
        .onChange(of: session.text.htmlMode) { newMode in
            guard PreviewTypeClassifier.isHtmlFile(item.url.pathExtension) else { return }
            if newMode == .source, session.content.textContent.isEmpty {
                Task { await session.loadTextContentIfNeeded() }
            }
        }
        .onChange(of: session.archive.extractAction) { action in
            guard let action else { return }
            let archiveItem = session.browseTarget
            defer { session.archive.extractAction = nil }
            switch action {
            case .copyList:
                break
            case .extractHere:
                ArchiveOperations.extract(archives: [archiveItem], mode: .here) { _ in }
            case .extractTo:
                ArchiveOperations.extractToPanel(archives: [archiveItem]) { _ in }
            case .extractSelectedHere, .extractSelectedTo:
                let members = ArchiveMemberPathResolver.resolveMemberPaths(
                    selectedPaths: session.archive.selectedEntryPaths,
                    allEntries: session.content.archiveEntries
                )
                guard !members.isEmpty else { return }
                if action == .extractSelectedHere {
                    ArchiveOperations.extractPartial(
                        archive: archiveItem,
                        memberPaths: members,
                        mode: .here
                    ) { _ in }
                } else {
                    guard let destination = ArchiveExtractPanel.pickDestinationDirectory() else { return }
                    ArchiveOperations.extractPartial(
                        archive: archiveItem,
                        memberPaths: members,
                        mode: .destination(destination)
                    ) { _ in }
                }
            }
        }
        .onChange(of: session.image.previewAction) { action in
            guard let action else { return }
            switch action {
            case .save:
                Task { await session.saveEditedImage() }
            }
            DispatchQueue.main.async { session.image.previewAction = nil }
        }
        .onChange(of: session.text.previewAction) { action in
            guard let action else { return }
            switch action {
            case .beginEdit:
                session.enterTextEditMode()
                DispatchQueue.main.async { session.text.previewAction = nil }
            case .save:
                Task { await session.saveEditedText() }
                DispatchQueue.main.async { session.text.previewAction = nil }
            case .revert:
                Task { _ = await session.revertTextEdits() }
                DispatchQueue.main.async { session.text.previewAction = nil }
            case .copyAll, .scrollTop, .scrollBottom:
                break
            }
        }
        .onChange(of: session.image.zoomAction) { action in
            guard action == .actualSize else { return }
            Task { await session.upgradeImageToFullResolutionIfNeeded() }
        }
        .alert(L10n.Preview.saveFailedTitle, isPresented: Binding(
            get: { session.content.imageSaveErrorMessage != nil },
            set: { if !$0 { session.content.imageSaveErrorMessage = nil } }
        )) {
            Button(L10n.Action.ok, role: .cancel) {}
        } message: {
            Text(session.content.imageSaveErrorMessage ?? "")
        }
        .alert(L10n.Preview.saveFailedTitle, isPresented: Binding(
            get: { session.content.textSaveErrorMessage != nil },
            set: { if !$0 { session.content.textSaveErrorMessage = nil } }
        )) {
            Button(L10n.Action.ok, role: .cancel) {}
        } message: {
            Text(session.content.textSaveErrorMessage ?? "")
        }
    }

    @MainActor
    private func applyLoadTaskIfNeeded() async {
        let taskID = contentLoadTaskID

        if lastAppliedLoadTaskID == taskID {
            // 上次 beginLoadTask 已登记，但任务可能被 cancel 导致永远停在 .loading。
            if case .loading = session.content.loadPhase {
                lastAppliedLoadTaskID = nil
            } else {
                return
            }
        }

        if session.content.loadPhase == .loaded,
           !session.isLoading,
           session.contentLoadedItemID == session.browseTarget.id {
            lastAppliedLoadTaskID = taskID
            return
        }

        if session.browseContext != nil {
            if await session.tryApplyPrefetchedBrowseContent() {
                lastAppliedLoadTaskID = taskID
                return
            }
        }

        if session.browseContext != nil, lastAppliedLoadTaskID != nil {
            try? await Task.sleep(nanoseconds: PreviewBrowserStripMetrics.switchDebounceMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
        }

        guard lastAppliedLoadTaskID != taskID else { return }

        lastAppliedLoadTaskID = taskID
        session.cancelLoad()
        session.resetControls()
        session.beginLoadTask(customPreviewRevision: Int(customPreviewStore.revision))
    }
}

