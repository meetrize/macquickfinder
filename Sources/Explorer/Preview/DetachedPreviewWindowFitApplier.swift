import AppKit

@MainActor
enum DetachedPreviewWindowFitApplier {
    static func applyIfNeeded(sessionID: PreviewSessionID) {
        guard let session = PreviewSessionStore.shared.session(for: sessionID) else { return }
        let pixelSize = session.image.sourcePixelSize.width > 0
            ? session.image.sourcePixelSize
            : ImageFileDimensionsReader.pixelSize(for: session.file.url)
        guard let pixelSize, pixelSize.width > 0, pixelSize.height > 0 else { return }

        let window = NSApplication.shared.windows.first { window in
            window.isVisible && window.title == session.previewContentItem?.name
        }
        guard let window else { return }

        session.image.zoomScale = 1.0
        DetachedPreviewWindowSizer.apply(
            to: window,
            imagePixelSize: pixelSize,
            browserStripExpanded: session.isBrowserStripExpanded,
            canBrowse: session.browseContext?.canBrowse ?? false
        )
    }
}
