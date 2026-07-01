import AppKit
import Foundation

extension PreviewSession {
    /// 浏览模式下若相邻文件已预取，直接解码展示，跳过 loading 态与防抖等待。
    func tryApplyPrefetchedBrowseContent() async -> Bool {
        guard browseContext != nil else { return false }

        let item = browseTarget
        let itemID = item.id
        guard browseContentPrefetcher.hasCached(for: itemID) else { return false }
        guard PreviewBrowserContentPrefetcher.isPrefetchEligible(item) else { return false }
        guard let prefetched = browseContentPrefetcher.consume(for: itemID) else { return false }

        let url = item.url
        let ext = url.pathExtension.lowercased()
        let customMode = CustomPreviewRuleStore.shared.overridingRule(for: ext)?.mode

        cancelLoad()
        resetControls()

        let applied: Bool
        if resolvesToImagePreview(extension: ext, customMode: customMode) {
            let maxPixelSize = imagePreviewDisplayMaxPixelSize(for: url)
            let decoded = await ImagePreviewLoader.decodeImage(data: prefetched, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled, browseTarget.id == itemID, let decoded else { return false }
            applied = applyDecodedImage(
                decoded,
                sourceURL: url,
                maxPixelSize: maxPixelSize,
                expectedItemID: itemID
            )
        } else if resolvesToPDFPreview(extension: ext, customMode: customMode) {
            guard !Task.isCancelled, browseTarget.id == itemID else { return false }
            applied = applyLoadPayload(PreviewLoadPayload(pdfData: prefetched), expectedItemID: itemID)
        } else {
            return false
        }

        guard applied else { return false }

        scheduleBrowseContentPrefetch(
            settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
        )
        return true
    }

    private func resolvesToImagePreview(extension ext: String, customMode: CustomPreviewMode?) -> Bool {
        if customMode == .image { return true }
        if customMode != nil { return false }
        return BuiltinPreviewExtensions.image.contains(ext)
    }

    private func resolvesToPDFPreview(extension ext: String, customMode: CustomPreviewMode?) -> Bool {
        if customMode == .pdf { return true }
        if customMode != nil { return false }
        return BuiltinPreviewExtensions.pdf.contains(ext)
    }
}
