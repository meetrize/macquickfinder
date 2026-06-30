import AppKit
import Foundation

extension PreviewSession {
    func currentImagePreviewPixelBudget() -> Int {
        ImagePreviewDisplayMetrics.pixelBudget(
            containerSize: image.displayContainerSize,
            screenScale: image.displayScreenScale
        )
    }

    func updateImagePreviewDisplayMetrics(containerSize: CGSize, screenScale: CGFloat) {
        image.displayContainerSize = containerSize
        image.displayScreenScale = max(screenScale, 1)
    }

    func imagePreviewDisplayMaxPixelSize(for url: URL) -> Int? {
        let sourceSize = ImageFileDimensionsReader.pixelSize(for: url) ?? .zero
        let budget = currentImagePreviewPixelBudget()
        return ImagePreviewLoader.recommendedMaxPixelSize(
            sourcePixelSize: sourceSize,
            displayPixelBudget: budget
        )
    }

    @discardableResult
    func applyDecodedImage(
        _ decodedImage: NSImage,
        sourceURL: URL,
        maxPixelSize: Int?,
        expectedItemID: String
    ) -> Bool {
        guard !Task.isCancelled, browseTarget.id == expectedItemID else { return false }

        content.image = decodedImage
        if let fileSize = ImageFileDimensionsReader.pixelSize(for: sourceURL) {
            image.sourcePixelSize = fileSize
        } else {
            image.sourcePixelSize = ImagePreviewTransformApplier.pixelSize(of: decodedImage)
        }
        image.decodedMaxPixelSize = maxPixelSize ?? 0
        content.loadPhase = .loaded
        return true
    }

    @discardableResult
    func applyImagePreview(
        data: Data,
        url: URL,
        maxPixelSize: Int?,
        expectedItemID: String
    ) -> Bool {
        guard !Task.isCancelled, browseTarget.id == expectedItemID else { return false }

        guard let decoded = ImagePreviewLoader.decode(data: data, maxPixelSize: maxPixelSize) else {
            content.image = nil
            image.sourcePixelSize = .zero
            image.decodedMaxPixelSize = 0
            content.loadPhase = .failed("Unable to decode image format")
            return true
        }
        return applyDecodedImage(
            decoded,
            sourceURL: url,
            maxPixelSize: maxPixelSize,
            expectedItemID: expectedItemID
        )
    }

    func upgradeImageToFullResolutionIfNeeded() async {
        guard image.isDisplayResolutionLimited else { return }
        let item = browseTarget
        let url = item.url
        let itemID = item.id
        guard let fullImage = await ImagePreviewLoader.loadImage(from: url, maxPixelSize: nil) else { return }
        guard !Task.isCancelled, browseTarget.id == itemID else { return }
        _ = applyDecodedImage(fullImage, sourceURL: url, maxPixelSize: nil, expectedItemID: itemID)
    }

    func performImageEdit(_ action: @escaping () -> Void) {
        Task {
            await upgradeImageToFullResolutionIfNeeded()
            await MainActor.run {
                image.performEdit(action)
            }
        }
    }
}
