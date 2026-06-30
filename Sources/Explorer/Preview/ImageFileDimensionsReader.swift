import CoreGraphics
import Foundation
import ImageIO

enum ImageFileDimensionsReader {
    /// 通过 ImageIO 读取像素尺寸，避免完整解码。
    static func pixelSize(for url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}

enum ExternalImageFileClassifier {
    static func isExternalImagePreviewCandidate(_ url: URL) -> Bool {
        guard !url.hasDirectoryPath else { return false }
        let ext = url.pathExtension.lowercased()
        if BuiltinPreviewExtensions.image.contains(ext) { return true }
        if BuiltinPreviewExtensions.quickLookImage.contains(ext) { return true }
        return false
    }

    static func imageURLs(from urls: [URL]) -> [URL] {
        urls.filter(isExternalImagePreviewCandidate)
    }
}
