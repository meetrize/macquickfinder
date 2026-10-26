import AppKit
import Foundation
import PDFKit
import QuickLookThumbnailing

/// 悬停预览分级加载：可取消、有超时，禁止创建 `PreviewSession`。
enum HoverPreviewLoader {
    @MainActor
    static func load(
        item: FileItem,
        generation: UInt,
        isCurrent: @escaping @MainActor (UInt) -> Bool
    ) async -> HoverPreviewPayload? {
        let cacheKey = HoverPreviewCache.makeKey(
            path: item.url.path,
            modificationDate: item.modificationDate,
            size: item.size
        )
        if let cached = HoverPreviewCache.shared.payload(for: cacheKey) {
            return cached
        }

        let ext = item.url.pathExtension.lowercased()
        let result: HoverPreviewPayload?
        if BuiltinPreviewExtensions.image.contains(ext) {
            result = await loadImage(item: item, generation: generation, isCurrent: isCurrent)
        } else if BuiltinPreviewExtensions.quickLookImage.contains(ext) {
            result = await loadQuickLookThumbnail(item: item, generation: generation, isCurrent: isCurrent)
        } else if BuiltinPreviewExtensions.pdf.contains(ext) {
            result = await loadPDFFirstPage(item: item, generation: generation, isCurrent: isCurrent)
        } else if BuiltinPreviewExtensions.text.contains(ext) || isCustomTextLike(ext) {
            result = await loadTextHead(item: item, generation: generation, isCurrent: isCurrent)
        } else if BuiltinPreviewExtensions.media.contains(ext) {
            result = metaPayload(for: item, kind: item.fileType.isEmpty ? "Media" : item.fileType)
        } else {
            result = await loadQuickLookThumbnail(item: item, generation: generation, isCurrent: isCurrent)
                ?? metaPayload(for: item, kind: item.fileType.isEmpty ? "File" : item.fileType)
        }

        guard isCurrent(generation), let result else { return nil }
        HoverPreviewCache.shared.store(result, for: cacheKey)
        return result
    }

    @MainActor
    private static func isCustomTextLike(_ ext: String) -> Bool {
        guard let mode = CustomPreviewRuleStore.shared.activeMode(for: ext) else { return false }
        switch mode {
        case .text, .markdown, .html:
            return true
        default:
            return false
        }
    }

    private static func metaPayload(for item: FileItem, kind: String) -> HoverPreviewPayload {
        .meta(
            HoverPreviewMeta(
                title: item.name,
                subtitle: kind,
                detail: item.sizeDisplay.isEmpty ? nil : item.sizeDisplay
            )
        )
    }

    private static func loadImage(
        item: FileItem,
        generation: UInt,
        isCurrent: @escaping @MainActor (UInt) -> Bool
    ) async -> HoverPreviewPayload? {
        if item.size > HoverPreviewMetrics.maxSourceBytesForFullDecode {
            return await loadQuickLookThumbnail(item: item, generation: generation, isCurrent: isCurrent)
        }
        let maxPixel = HoverPreviewMetrics.maxPixelEdge
        let image = await raceAgainstTimeout(HoverPreviewMetrics.loadTimeout) {
            await ImagePreviewLoader.loadImage(from: item.url, maxPixelSize: maxPixel)
        }
        guard await isCurrent(generation), let image else { return nil }
        return .image(image)
    }

    private static func loadPDFFirstPage(
        item: FileItem,
        generation: UInt,
        isCurrent: @escaping @MainActor (UInt) -> Bool
    ) async -> HoverPreviewPayload? {
        let url = item.url
        let maxEdge = CGFloat(HoverPreviewMetrics.maxPixelEdge)
        let image = await raceAgainstTimeout(HoverPreviewMetrics.loadTimeout) {
            await renderPDFFirstPage(url: url, maxEdge: maxEdge)
        }
        guard await isCurrent(generation), let image else { return nil }
        return .image(image)
    }

    private static func renderPDFFirstPage(url: URL, maxEdge: CGFloat) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    guard let document = PDFDocument(url: url),
                          let page = document.page(at: 0) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let pageRect = page.bounds(for: .mediaBox)
                    guard pageRect.width > 0, pageRect.height > 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let scale = min(maxEdge / pageRect.width, maxEdge / pageRect.height, 1)
                    let size = NSSize(width: pageRect.width * scale, height: pageRect.height * scale)
                    let image = NSImage(size: size)
                    image.lockFocus()
                    if let context = NSGraphicsContext.current?.cgContext {
                        context.saveGState()
                        context.translateBy(x: 0, y: size.height)
                        context.scaleBy(x: scale, y: -scale)
                        page.draw(with: .mediaBox, to: context)
                        context.restoreGState()
                    }
                    image.unlockFocus()
                    continuation.resume(returning: image)
                }
            }
        }
    }

    private static func loadTextHead(
        item: FileItem,
        generation: UInt,
        isCurrent: @escaping @MainActor (UInt) -> Bool
    ) async -> HoverPreviewPayload? {
        let url = item.url
        let limit = HoverPreviewMetrics.textPreviewMaxBytes
        let text = await raceAgainstTimeout(HoverPreviewMetrics.loadTimeout) {
            await readTextHead(url: url, limit: limit)
        }
        guard await isCurrent(generation), let text else { return nil }
        return .text(text)
    }

    private static func readTextHead(url: URL, limit: Int) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    guard let handle = try? FileHandle(forReadingFrom: url) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    defer { try? handle.close() }
                    let data = handle.readData(ofLength: limit)
                    let string = String(data: data, encoding: .utf8)
                        ?? String(decoding: data, as: UTF8.self)
                    continuation.resume(returning: string)
                }
            }
        }
    }

    private static func loadQuickLookThumbnail(
        item: FileItem,
        generation: UInt,
        isCurrent: @escaping @MainActor (UInt) -> Bool
    ) async -> HoverPreviewPayload? {
        let url = item.url
        let maxEdge = CGFloat(HoverPreviewMetrics.maxPixelEdge)
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2 }
        let image = await raceAgainstTimeout(HoverPreviewMetrics.loadTimeout) {
            await generateQuickLookThumbnail(url: url, maxEdge: maxEdge, scale: scale)
        }
        guard await isCurrent(generation), let image else { return nil }
        return .image(image)
    }

    private static func generateQuickLookThumbnail(
        url: URL,
        maxEdge: CGFloat,
        scale: CGFloat
    ) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: maxEdge, height: maxEdge),
                scale: scale,
                representationTypes: .thumbnail
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }

    /// 超时竞赛；不用 `TaskGroup`+`Sendable`，以便在 macOS 13 上携带 `NSImage`。
    private static func raceAgainstTimeout<T>(
        _ seconds: TimeInterval,
        operation: @escaping () async -> T?
    ) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let lock = NSLock()
            var finished = false
            func finish(_ value: T?) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                continuation.resume(returning: value)
            }
            Task {
                let value = await operation()
                finish(value)
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                finish(nil)
            }
        }
    }
}
