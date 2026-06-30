import Foundation

extension PreviewSession {
    func loadCustomPreview(mode: CustomPreviewMode, url: URL, itemID: String) async {
        switch mode {
        case .quickLook:
            guard !Task.isCancelled else { return }
            applyLoadPayload(.office(url: url), expectedItemID: itemID)
        case .media:
            guard !Task.isCancelled else { return }
            applyLoadPayload(.media(url: url), expectedItemID: itemID)
        case .image:
            let maxPixelSize = imagePreviewDisplayMaxPixelSize(for: url)
            if let prefetched = browseContentPrefetcher.consume(for: itemID) {
                guard !Task.isCancelled else { return }
                applyLoadPayload(
                    PreviewLoadPayload(imageData: prefetched, imageMaxPixelSize: maxPixelSize),
                    expectedItemID: itemID
                )
                return
            }
            guard let decodedImage = await ImagePreviewLoader.loadImage(from: url, maxPixelSize: maxPixelSize) else {
                guard !Task.isCancelled else { return }
                applyLoadPayload(.failure("Unable to decode image format"), expectedItemID: itemID)
                return
            }
            guard !Task.isCancelled else { return }
            _ = applyDecodedImage(
                decodedImage,
                sourceURL: url,
                maxPixelSize: maxPixelSize,
                expectedItemID: itemID
            )
        case .pdf:
            let pdfData = await PreviewContentLoader.loadMappedData(from: url)
            guard !Task.isCancelled else { return }
            if let pdfData {
                applyLoadPayload(PreviewLoadPayload(pdfData: pdfData), expectedItemID: itemID)
            } else {
                applyLoadPayload(.failure("Unable to load PDF document"), expectedItemID: itemID)
            }
        case .html where text.htmlMode == .preview:
            guard !Task.isCancelled else { return }
            applyLoadPayload(.unavailable, expectedItemID: itemID)
            scheduleDeferredTextLoad(from: url, itemID: itemID)
        case .text, .markdown, .html:
            do {
                let loadedText = try await PreviewContentLoader.loadText(from: url)
                guard !Task.isCancelled else { return }
                applyLoadPayload(.text(loadedText), expectedItemID: itemID)
            } catch {
                guard !Task.isCancelled else { return }
                if error is CancellationError { return }
                applyLoadPayload(.failure(error.localizedDescription), expectedItemID: itemID)
            }
        case .archive:
            await consumeArchiveEntryStream(replacingExisting: true)
        }
    }
}
