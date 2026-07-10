import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// 预览图片加载：ImageIO 按需降采样，避免 `NSImage(data:)` 全分辨率解码。
enum ImagePreviewLoader {
    static let defaultDisplayPixelBudget = 4096

    static func recommendedMaxPixelSize(
        sourcePixelSize: CGSize,
        displayPixelBudget: Int = defaultDisplayPixelBudget
    ) -> Int? {
        let sourceMax = Int(max(sourcePixelSize.width, sourcePixelSize.height).rounded())
        guard sourceMax > 0 else { return nil }
        if sourceMax <= displayPixelBudget { return nil }
        return displayPixelBudget
    }

    static func loadImage(from url: URL, maxPixelSize: Int?) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = decodeFromURL(url, maxPixelSize: maxPixelSize)
                continuation.resume(returning: image)
            }
        }
    }

    static func decode(data: Data, maxPixelSize: Int?) -> NSImage? {
        autoreleasepool {
            if SVGPreviewSupport.isSVGData(data) {
                return SVGPreviewSupport.decode(data: data, maxPixelSize: maxPixelSize)
            }
            if EPSPreviewSupport.isEPSData(data) {
                return EPSPreviewSupport.decode(data: data, maxPixelSize: maxPixelSize)
            }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return decodeFromSource(source, maxPixelSize: maxPixelSize)
        }
    }

    static func decodeImage(data: Data, maxPixelSize: Int?) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = decode(data: data, maxPixelSize: maxPixelSize)
                continuation.resume(returning: image)
            }
        }
    }

    private static func decodeFromURL(_ url: URL, maxPixelSize: Int?) -> NSImage? {
        autoreleasepool {
            if SVGPreviewSupport.isSVGURL(url) {
                return SVGPreviewSupport.decode(from: url, maxPixelSize: maxPixelSize)
            }
            if EPSPreviewSupport.isEPSURL(url) {
                return EPSPreviewSupport.decode(from: url, maxPixelSize: maxPixelSize)
            }
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return decodeFromSource(source, maxPixelSize: maxPixelSize)
        }
    }

    private static func decodeFromSource(_ source: CGImageSource, maxPixelSize: Int?) -> NSImage? {
        guard CGImageSourceGetCount(source) > 0 else { return nil }

        let effectiveMax = effectiveMaxPixelSize(for: source, requested: maxPixelSize)
        let cgImage: CGImage?
        if let effectiveMax {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: effectiveMax,
                kCGImageSourceShouldCacheImmediately: false,
            ]
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        } else {
            let options: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: false,
            ]
            cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
        }

        guard let cgImage else { return nil }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    private static func effectiveMaxPixelSize(for source: CGImageSource, requested: Int?) -> Int? {
        guard let requested else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = props[kCGImagePropertyPixelHeight] as? CGFloat else {
            return requested
        }
        let sourceMax = Int(max(width, height).rounded())
        if sourceMax <= requested { return nil }
        return requested
    }
}
