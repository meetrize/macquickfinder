import SwiftUI
import AppKit
import FileList

struct FileContentView: View {
    @ObservedObject var session: PreviewSession
    @ObservedObject private var customPreviewStore = CustomPreviewRuleStore.shared
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

    private var showsCodeLineNumbers: Bool {
        codePreviewShowLineNumbers && PreviewTypeClassifier.isCodeFile(fileExtension)
    }

    private var imageResizePreviewIdentity: String {
        guard let size = session.image.resizeTargetSize else { return "image-original-size" }
        return "image-resize-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    private var loadTaskID: String {
        let contentID = session.browseTarget.id
        return "\(contentID)-\(session.archive.reloadToken)-\(customPreviewStore.revision)"
    }

    var body: some View {
        ZStack {
            if session.isLoading {
                ProgressView("Loading preview...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMsg = session.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()

                    Text("Error loading preview")
                        .font(.headline)

                    Text(errorMsg)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
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
                    pickedWebColor: $session.image.pickedWebColor
                )
                .id(imageResizePreviewIdentity)
            } else if let pdfDoc = session.content.pdfDocument {
                PDFPreview(
                    document: pdfDoc,
                    navigationAction: $session.pdf.navigateAction
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
            } else if let officeRichText = session.content.officeRichText {
                OfficeRichTextPreview(
                    attributedText: officeRichText,
                    wrapLines: session.text.wrapEnabled,
                    zoomScale: session.office.zoomScale
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let officeURL = session.content.officeURL {
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
                    expanded: session.archive.expanded,
                    copyAction: $session.archive.copyAction
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if isHtmlPreviewMode {
                HTMLFilePreview(fileURL: item.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !session.content.textContent.isEmpty {
                if usesMarkdownPreview {
                    MarkdownFilePreview(
                        markdown: session.content.textContent,
                        wrapLines: session.text.wrapEnabled,
                        zoomScale: $session.text.markdownPreviewScale
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextFilePreview(
                        text: session.content.textContent,
                        fileExtension: fileExtension,
                        wrapLines: session.text.wrapEnabled,
                        fontSize: PreviewTypeClassifier.isMarkdownFile(fileExtension) ? session.text.markdownSourceFontSize : NSFont.systemFontSize,
                        showLineNumbers: showsCodeLineNumbers,
                        previewTextSelectionActive: $previewTextSelectionActive,
                        action: $session.text.previewAction,
                        searchQuery: $session.text.searchQuery,
                        searchNextToken: $session.text.searchNextToken,
                        searchMatchCount: $session.text.searchMatchCount
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
                Text("Preview not available for this file type")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .opacity(contentOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusedValue(\.previewTextSelectionActive, previewTextSelectionActive)
        .task(id: loadTaskID) {
            await applyLoadTaskIfNeeded()
        }
        .onChange(of: session.browseTarget.id) { _ in
            previewTextSelectionActive = false
            guard session.browseContext != nil else { return }
            contentOpacity = 0.35
            withAnimation(.easeInOut(duration: PreviewBrowserStripMetrics.contentCrossfadeDuration)) {
                contentOpacity = 1
            }
        }
        .onChange(of: session.text.htmlMode) { newMode in
            guard PreviewTypeClassifier.isHtmlFile(item.url.pathExtension) else { return }
            if newMode == .source, session.content.textContent.isEmpty {
                Task { await session.loadTextContentIfNeeded() }
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
        .alert("保存失败", isPresented: Binding(
            get: { session.content.imageSaveErrorMessage != nil },
            set: { if !$0 { session.content.imageSaveErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(session.content.imageSaveErrorMessage ?? "")
        }
    }

    @MainActor
    private func applyLoadTaskIfNeeded() async {
        if lastAppliedLoadTaskID == loadTaskID {
            // 上次 beginLoadTask 已登记，但任务可能被 cancel 导致永远停在 .loading。
            if case .loading = session.content.loadPhase {
                lastAppliedLoadTaskID = nil
            } else {
                return
            }
        }

        if lastAppliedLoadTaskID == nil,
           session.content.loadPhase == .loaded,
           !session.isLoading {
            lastAppliedLoadTaskID = loadTaskID
            return
        }

        if session.browseContext != nil, lastAppliedLoadTaskID != nil {
            try? await Task.sleep(nanoseconds: PreviewBrowserStripMetrics.switchDebounceMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
        }

        guard lastAppliedLoadTaskID != loadTaskID else { return }

        lastAppliedLoadTaskID = loadTaskID
        session.cancelLoad()
        session.resetControls()
        session.beginLoadTask(customPreviewRevision: Int(customPreviewStore.revision))
    }
}

