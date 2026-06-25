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
        if let prefetched = browseContentPrefetcher.consume(for: itemID) {
            guard !Task.isCancelled else { return }
            applyLoadPayload(PreviewLoadPayload(imageData: prefetched), expectedItemID: itemID)
            scheduleBrowseContentPrefetch()
            return
        }
        let imageData = await PreviewContentLoader.loadMappedData(from: url)
        guard !Task.isCancelled else { return }
        if let imageData {
            applyLoadPayload(PreviewLoadPayload(imageData: imageData), expectedItemID: itemID)
        } else {
            applyLoadPayload(.failure("Unable to decode image format"), expectedItemID: itemID)
        }
        scheduleBrowseContentPrefetch()
    }

    private func loadBuiltInPDF(url: URL, itemID: String) async {
        if let prefetched = browseContentPrefetcher.consume(for: itemID) {
            guard !Task.isCancelled else { return }
            applyLoadPayload(PreviewLoadPayload(pdfData: prefetched), expectedItemID: itemID)
            scheduleBrowseContentPrefetch()
            return
        }
        let pdfData = await PreviewContentLoader.loadMappedData(from: url)
        guard !Task.isCancelled else { return }
        if let pdfData {
            applyLoadPayload(PreviewLoadPayload(pdfData: pdfData), expectedItemID: itemID)
        } else {
            applyLoadPayload(.failure("Unable to load PDF document"), expectedItemID: itemID)
        }
        scheduleBrowseContentPrefetch()
    }

    private func loadDOCXPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        if let richText = await PreviewContentLoader.loadDOCXRichText(from: url) {
            applyLoadPayload(.officeRichText(richText), expectedItemID: itemID)
        } else {
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
        }
    }

    private func loadDOCPreview(url: URL, itemID: String) async {
        guard !Task.isCancelled else { return }
        if let richText = await PreviewContentLoader.loadDOCRichText(from: url) {
            applyLoadPayload(.officeRichText(richText), expectedItemID: itemID)
        } else {
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
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

    private func loadArchivePreview(url: URL, itemID: String) async {
        do {
            let result = try await PreviewContentLoader.loadArchive(at: url)
            guard !Task.isCancelled else { return }
            applyLoadPayload(
                .archive(entries: result.entries, truncated: result.truncated),
                expectedItemID: itemID
            )
        } catch {
            if error is CancellationError { return }
            applyLoadPayload(.failure(error.localizedDescription), expectedItemID: itemID)
        }
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
