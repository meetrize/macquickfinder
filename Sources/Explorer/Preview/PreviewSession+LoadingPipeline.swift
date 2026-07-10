import Foundation

extension PreviewSession {
    func loadContent(customPreviewRevision: Int) async {
        let item = browseTarget
        let url = item.url
        let ext = url.pathExtension.lowercased()
        let itemID = item.id
        let customPreviewStore = CustomPreviewRuleStore.shared
        _ = customPreviewRevision

        let route = PreviewLoadDispatch.resolve(
            PreviewLoadDispatchInput(
                pathExtension: ext,
                fileName: url.lastPathComponent,
                isHtmlFile: PreviewTypeClassifier.isHtmlFile(ext),
                htmlPreviewMode: text.htmlMode,
                overridingMode: customPreviewStore.overridingRule(for: ext)?.mode,
                supplementalMode: customPreviewStore.activeMode(for: ext)
            )
        )

        switch route {
        case .customOverride(let mode):
            await loadCustomPreview(mode: mode, url: url, itemID: itemID)
        case .builtInImage:
            await loadBuiltInImage(url: url, itemID: itemID)
        case .builtInQuickLookImage:
            guard !Task.isCancelled else { return }
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
        case .builtInMedia:
            guard !Task.isCancelled else { return }
            applyLoadPayload(.media(url: url), expectedItemID: itemID)
        case .docx:
            await loadDOCXPreview(url: url, itemID: itemID)
        case .doc:
            await loadDOCPreview(url: url, itemID: itemID)
        case .xlsx, .xls:
            await loadSpreadsheetPreview(url: url, itemID: itemID)
        case .csv:
            await loadCSVPreview(url: url, itemID: itemID)
        case .rtf:
            await loadRTFPreview(url: url, itemID: itemID)
        case .epub:
            await loadEpubPreview(url: url, itemID: itemID)
        case .eml:
            await loadEmlPreview(url: url, itemID: itemID)
        case .font:
            await loadFontPreview(url: url, itemID: itemID)
        case .model3D:
            await loadModel3DPreview(url: url, itemID: itemID)
        case .builtInOffice:
            guard !Task.isCancelled else { return }
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
        case .builtInPDF:
            await loadBuiltInPDF(url: url, itemID: itemID)
        case .archive:
            await loadArchivePreview(url: url, itemID: itemID)
        case .builtInText(let deferSourceLoad):
            await loadBuiltInText(url: url, itemID: itemID, deferSourceLoad: deferSourceLoad)
        case .customSupplement(let mode):
            await loadCustomPreview(mode: mode, url: url, itemID: itemID)
        case .unavailable:
            guard !Task.isCancelled else { return }
            applyLoadPayload(.unavailable, expectedItemID: itemID)
        }
    }

    private func loadBuiltInImage(url: URL, itemID: String) async {
        let maxPixelSize = imagePreviewDisplayMaxPixelSize(for: url)
        if let prefetched = browseContentPrefetcher.consume(for: itemID) {
            guard !Task.isCancelled else { return }
            applyLoadPayload(
                PreviewLoadPayload(imageData: prefetched, imageMaxPixelSize: maxPixelSize),
                expectedItemID: itemID
            )
            scheduleBrowseContentPrefetch(
                settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
            )
            return
        }
        guard let decodedImage = await ImagePreviewLoader.loadImage(from: url, maxPixelSize: maxPixelSize) else {
            guard !Task.isCancelled else { return }
            let errorMessage: String = {
                if EPSPreviewSupport.isEPSURL(url), !EPSPreviewSupport.isGhostscriptAvailable {
                    return EPSPreviewSupport.missingGhostscriptMessage
                }
                return "Unable to decode image format"
            }()
            applyLoadPayload(.failure(errorMessage), expectedItemID: itemID)
            scheduleBrowseContentPrefetch(
                settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
            )
            return
        }
        guard !Task.isCancelled else { return }
        _ = applyDecodedImage(
            decodedImage,
            sourceURL: url,
            maxPixelSize: maxPixelSize,
            expectedItemID: itemID
        )
        scheduleBrowseContentPrefetch(
            settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
        )
    }

    private func loadBuiltInPDF(url: URL, itemID: String) async {
        if let prefetched = browseContentPrefetcher.consume(for: itemID) {
            guard !Task.isCancelled else { return }
            applyLoadPayload(PreviewLoadPayload(pdfData: prefetched), expectedItemID: itemID)
            scheduleBrowseContentPrefetch(
                settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
            )
            return
        }
        let pdfData = await PreviewContentLoader.loadMappedData(from: url)
        guard !Task.isCancelled else { return }
        if let pdfData {
            applyLoadPayload(PreviewLoadPayload(pdfData: pdfData), expectedItemID: itemID)
        } else {
            applyLoadPayload(.failure("Unable to load PDF document"), expectedItemID: itemID)
        }
        scheduleBrowseContentPrefetch(
            settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
        )
    }

    private func loadDOCXPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        if let richText = await PreviewContentLoader.loadDOCXRichText(from: url) {
            applyLoadPayload(.wordDocument(text: richText.string, richText: richText), expectedItemID: itemID)
            office.wordDocumentMode = .text
        } else {
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
            office.wordDocumentMode = .formatted
        }
    }

    private func loadDOCPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        if let richText = await PreviewContentLoader.loadDOCRichText(from: url) {
            applyLoadPayload(.wordDocument(text: richText.string, richText: richText), expectedItemID: itemID)
            office.wordDocumentMode = .text
        } else {
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
            office.wordDocumentMode = .formatted
        }
    }

    private func loadRTFPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        if let richText = await PreviewContentLoader.loadRTFRichText(from: url) {
            applyLoadPayload(.wordDocument(text: richText.string, richText: richText), expectedItemID: itemID)
            office.wordDocumentMode = .formatted
        } else {
            applyLoadPayload(.failure("Unable to load RTF document"), expectedItemID: itemID)
        }
    }

    private func loadEpubPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        let result = await PreviewContentLoader.loadEpub(from: url)
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let package):
            applyLoadPayload(.epub(package), expectedItemID: itemID)
            epub.currentChapterIndex = 0
        case .failure(let error):
            applyLoadPayload(.failure(error.localizedDescription), expectedItemID: itemID)
        }
    }

    private func loadEmlPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        let result = await PreviewContentLoader.loadEml(from: url)
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let content):
            applyLoadPayload(.eml(content), expectedItemID: itemID)
        case .failure(let error):
            applyLoadPayload(.failure(error.localizedDescription), expectedItemID: itemID)
        }
    }

    private func loadFontPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        let result = await PreviewContentLoader.loadFont(from: url)
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let content):
            applyLoadPayload(.font(content), expectedItemID: itemID)
        case .failure(let error):
            applyLoadPayload(.failure(error.localizedDescription), expectedItemID: itemID)
        }
    }

    private func loadModel3DPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        let result = await PreviewContentLoader.loadModel3D(from: url)
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let content):
            applyLoadPayload(.model3D(content), expectedItemID: itemID)
        case .failure(let error):
            applyLoadPayload(.failure(error.localizedDescription), expectedItemID: itemID)
        }
    }

    private func loadSpreadsheetPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        if let text = await PreviewContentLoader.loadSpreadsheetText(from: url) {
            applyLoadPayload(.spreadsheetText(text, officeURL: url), expectedItemID: itemID)
            office.spreadsheetMode = .text
        } else {
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
            office.spreadsheetMode = .quickLook
        }
    }

    private func loadCSVPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        do {
            let loadedText = try await PreviewContentLoader.loadText(from: url)
            applyLoadPayload(.spreadsheetText(loadedText, officeURL: url), expectedItemID: itemID)
            office.spreadsheetMode = .text
        } catch {
            guard !Task.isCancelled else { return }
            if error is CancellationError { return }
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
            office.spreadsheetMode = .quickLook
        }
    }

    private func loadArchivePreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        await consumeArchiveEntryStream(replacingExisting: true)
    }

    private func loadBuiltInText(url: URL, itemID: String, deferSourceLoad: Bool) async {
        if deferSourceLoad {
            guard !Task.isCancelled else { return }
            applyLoadPayload(.unavailable, expectedItemID: itemID)
            scheduleDeferredTextLoad(from: url, itemID: itemID)
            return
        }

        do {
            let loadedText = try await PreviewContentLoader.loadText(from: url)
            guard !Task.isCancelled else { return }
            applyLoadPayload(.text(loadedText), expectedItemID: itemID)
        } catch {
            guard !Task.isCancelled else { return }
            if error is CancellationError { return }
            applyLoadPayload(.failure(error.localizedDescription), expectedItemID: itemID)
        }
    }
}
