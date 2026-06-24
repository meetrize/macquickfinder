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
            let imageData = await PreviewContentLoader.loadMappedData(from: url)
            guard !Task.isCancelled else { return }
            if let imageData {
                applyLoadPayload(PreviewLoadPayload(imageData: imageData), expectedItemID: itemID)
            } else {
                applyLoadPayload(.failure("Unable to decode image format"), expectedItemID: itemID)
            }
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
        }
    }
}
