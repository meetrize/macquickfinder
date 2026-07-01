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
        contentLoadedItemID = expectedItemID
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

    /// 预览区变大时在后台提高解码分辨率，不进入 loading 态、不清空当前图片。
    func scheduleImagePreviewResolutionUpgradeIfNeeded() {
        imageResolutionUpgradeTask?.cancel()
        imageResolutionUpgradeTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: PreviewBrowserStripMetrics.imageResolutionUpgradeDebounceMilliseconds * 1_000_000
            )
            guard !Task.isCancelled else { return }
            await self?.upgradeImagePreviewResolutionIfNeeded()
        }
    }

    func upgradeImagePreviewResolutionIfNeeded() async {
        guard content.image != nil else { return }
        guard case .loaded = content.loadPhase else { return }

        let item = browseTarget
        let url = item.url
        let itemID = item.id
        let ext = url.pathExtension.lowercased()
        let customMode = CustomPreviewRuleStore.shared.overridingRule(for: ext)?.mode
        guard isImagePreviewRoute(extension: ext, customMode: customMode) else { return }

        let desiredMax = imagePreviewDisplayMaxPixelSize(for: url)
        guard needsHigherImagePreviewResolution(desiredMax: desiredMax) else { return }

        guard let decoded = await ImagePreviewLoader.loadImage(from: url, maxPixelSize: desiredMax) else { return }
        guard !Task.isCancelled, browseTarget.id == itemID else { return }
        _ = applyDecodedImage(
            decoded,
            sourceURL: url,
            maxPixelSize: desiredMax,
            expectedItemID: itemID
        )
    }

    private func needsHigherImagePreviewResolution(desiredMax: Int?) -> Bool {
        if image.decodedMaxPixelSize == 0 { return false }
        guard let desiredMax else { return image.decodedMaxPixelSize > 0 }
        return desiredMax > image.decodedMaxPixelSize
    }

    private func isImagePreviewRoute(extension ext: String, customMode: CustomPreviewMode?) -> Bool {
        if customMode == .image { return true }
        if customMode != nil { return false }
        return BuiltinPreviewExtensions.image.contains(ext)
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
