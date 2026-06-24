import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImagePreviewSaveError: LocalizedError {
    case unableToEncode
    case unableToWrite

    var errorDescription: String? {
        switch self {
        case .unableToEncode:
            return "无法编码图片"
        case .unableToWrite:
            return "无法写入文件"
        }
    }
}

enum ImagePreviewTransformApplier {
    static func pixelSize(of image: NSImage) -> CGSize {
        if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return image.size
    }

    static func orientedPixelSize(of image: NSImage, rotationQuarterTurns: Int) -> CGSize {
        let source = pixelSize(of: image)
        let turns = ((rotationQuarterTurns % 4) + 4) % 4
        if turns % 2 != 0 {
            return CGSize(width: source.height, height: source.width)
        }
        return source
    }

    static func apply(
        to image: NSImage,
        rotationQuarterTurns: Int,
        flipHorizontal: Bool,
        flipVertical: Bool
    ) -> NSImage? {
        let turns = ((rotationQuarterTurns % 4) + 4) % 4
        guard turns != 0 || flipHorizontal || flipVertical else {
            return image.copy() as? NSImage ?? image
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let isSideways = turns % 2 != 0
        let outWidth = isSideways ? height : width
        let outHeight = isSideways ? width : height
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard let context = CGContext(
            data: nil,
            width: outWidth,
            height: outHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.translateBy(x: CGFloat(outWidth) / 2, y: CGFloat(outHeight) / 2)
        context.rotate(by: CGFloat(turns) * .pi / 2)
        context.scaleBy(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
        context.draw(
            cgImage,
            in: CGRect(
                x: -CGFloat(width) / 2,
                y: -CGFloat(height) / 2,
                width: CGFloat(width),
                height: CGFloat(height)
            )
        )

        guard let output = context.makeImage() else { return nil }
        return NSImage(cgImage: output, size: NSSize(width: outWidth, height: outHeight))
    }

    static func resize(_ image: NSImage, to targetSize: CGSize) -> NSImage? {
        let width = Int(targetSize.width.rounded())
        let height = Int(targetSize.height.rounded())
        guard width > 0, height > 0,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )

        guard let output = context.makeImage() else { return nil }
        return NSImage(cgImage: output, size: NSSize(width: width, height: height))
    }

    static func write(_ image: NSImage, to url: URL) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImagePreviewSaveError.unableToEncode
        }

        let ext = url.pathExtension.lowercased()

        if ext == "heic" || ext == "heif" {
            guard let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.heic.identifier as CFString,
                1,
                nil
            ) else {
                throw ImagePreviewSaveError.unableToEncode
            }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw ImagePreviewSaveError.unableToWrite
            }
            return
        }

        if ext == "webp",
           let destination = CGImageDestinationCreateWithURL(
               url as CFURL,
               UTType.webP.identifier as CFString,
               1,
               nil
           ) {
            CGImageDestinationAddImage(destination, cgImage, nil)
            if CGImageDestinationFinalize(destination) {
                return
            }
        }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw ImagePreviewSaveError.unableToEncode
        }

        let fileType: NSBitmapImageRep.FileType
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        switch ext {
        case "jpg", "jpeg":
            fileType = .jpeg
            properties[.compressionFactor] = 0.92
        case "png":
            fileType = .png
        case "gif":
            fileType = .gif
        case "tiff", "tif":
            fileType = .tiff
        case "bmp":
            fileType = .bmp
        default:
            fileType = .png
        }

        guard let data = rep.representation(using: fileType, properties: properties) else {
            throw ImagePreviewSaveError.unableToEncode
        }
        try data.write(to: url, options: .atomic)
    }

    static func sampleWebColor(from image: NSImage, normalizedPoint: CGPoint) -> String? {
        guard normalizedPoint.x >= 0, normalizedPoint.x <= 1,
              normalizedPoint.y >= 0, normalizedPoint.y <= 1,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let x = min(max(Int(normalizedPoint.x * CGFloat(width)), 0), max(width - 1, 0))
        let y = min(max(Int((1 - normalizedPoint.y) * CGFloat(height)), 0), max(height - 1, 0))

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: width, height: height)
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return nil }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
