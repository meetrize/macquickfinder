import CoreGraphics
import Foundation
import ImageIO

enum ImageFileDimensionsReader {
    /// 通过 ImageIO 读取像素尺寸，避免完整解码。
    static func pixelSize(for url: URL) -> CGSize? {
        if SVGPreviewSupport.isSVGURL(url),
           let data = try? Data(contentsOf: url),
           let markup = SVGPreviewSupport.markupStringForDimensions(from: data),
           let logicalSize = SVGPreviewSupport.logicalSize(from: markup) {
            return logicalSize
        }

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
