import AppKit
import CoreGraphics
import Foundation

/// 缩略图网格布局常量。
public enum FileListThumbnailMetrics {
    public static let minCellSize: CGFloat = 64
    public static let maxCellSize: CGFloat = 256
    public static let defaultCellSize: CGFloat = 128
    public static let cellSizeStep: CGFloat = 8
    public static let cellSpacing: CGFloat = 4
    public static let contentInset: CGFloat = 8
    public static let labelOverlayHeight: CGFloat = 20
    public static let sizeBadgeCornerRadius: CGFloat = 4
    public static let overlayLabelVerticalInset: CGFloat = 2
    public static let overlaySizeLabelExtraDownshift: CGFloat = 2
    public static let folderCountFontSize: CGFloat = 15
    public static let folderCountDownshift: CGFloat = 5
    public static let folderCountTextAlpha: CGFloat = 0.72
    public static let iconContentInsetRatio: CGFloat = 0.12
    public static let selectionBorderWidth: CGFloat = 2
    public static let cellCornerRadius: CGFloat = 4
    
    public static func clamp(cellSize: CGFloat) -> CGFloat {
        min(max(cellSize, minCellSize), maxCellSize)
    }
    
    public static func steppedCellSize(from value: CGFloat) -> CGFloat {
        let clamped = clamp(cellSize: value)
        let steps = round((clamped - minCellSize) / cellSizeStep)
        return minCellSize + steps * cellSizeStep
    }
    
    public static func thumbnailSizeBucket(for cellSize: CGFloat) -> Int {
        Int(steppedCellSize(from: cellSize) / cellSizeStep) * Int(cellSizeStep)
    }
    
    /// 图标在格子内 aspectFit 的目标边长（扣除内边距后）。
    public static func iconFittingSide(in cellSide: CGFloat) -> CGFloat {
        let inset = cellSide * iconContentInsetRatio
        return max(1, cellSide - inset * 2)
    }
    
    /// 将系统图标缩放到格子内的目标显示尺寸。
    public static func scaledIcon(_ image: NSImage, cellSize: CGFloat) -> NSImage {
        let side = iconFittingSide(in: cellSize)
        guard side > 0 else { return image }
        guard let copy = image.copy() as? NSImage else { return image }
        copy.size = NSSize(width: side, height: side)
        return copy
    }
    
    /// 「..」返回上一级：与缩略图文件夹同源的高清系统文件夹图标，桔色着色并叠加向上箭头。
    public static func parentDirectoryIcon(cellSize: CGFloat, scale: CGFloat) -> NSImage {
        let logicalSide = iconFittingSide(in: cellSize)
        let bucket = thumbnailSizeBucket(for: cellSize)
        let scaleKey = Int((scale * 100).rounded())
        let cacheKey = "parent_\(bucket)_\(scaleKey)"
        
        parentDirectoryIconCacheLock.lock()
        if let cached = parentDirectoryIconCache[cacheKey] {
            parentDirectoryIconCacheLock.unlock()
            return cached
        }
        parentDirectoryIconCacheLock.unlock()
        
        let rendered = renderParentDirectoryIcon(logicalSide: logicalSide, scale: scale)
        rendered.size = NSSize(width: logicalSide, height: logicalSide)
        
        parentDirectoryIconCacheLock.lock()
        parentDirectoryIconCache[cacheKey] = rendered
        parentDirectoryIconCacheLock.unlock()
        return rendered
    }
    
    /// 返回上一级文件夹着色：饱和度较高、整体偏淡的暖桔色。
    private static let parentDirectoryOrange = NSColor(red: 0.97, green: 0.71, blue: 0.40, alpha: 1)
    private static var parentDirectoryIconCache: [String: NSImage] = [:]
    private static let parentDirectoryIconCacheLock = NSLock()
    
    private static func renderParentDirectoryIcon(logicalSide: CGFloat, scale: CGFloat) -> NSImage {
        let pixelDimension = max(1, (logicalSide * scale).rounded(.toNearestOrAwayFromZero))
        let pixelCount = Int(pixelDimension)
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelCount,
            pixelsHigh: pixelCount,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return tintedFolderFallback(logicalSide: logicalSide)
        }
        rep.size = NSSize(width: logicalSide, height: logicalSide)
        
        let folderSource = NSWorkspace.shared.icon(for: .folder)
        let bounds = NSRect(x: 0, y: 0, width: logicalSide, height: logicalSide)
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        
        parentDirectoryOrange.setFill()
        bounds.fill()
        folderSource.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: folderSource.size),
            operation: .destinationIn,
            fraction: 1
        )
        
        drawParentDirectoryArrow(in: bounds, scale: scale)
        
        NSGraphicsContext.restoreGraphicsState()
        
        let image = NSImage(size: NSSize(width: logicalSide, height: logicalSide))
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }
    
    private static func drawParentDirectoryArrow(in bounds: NSRect, scale: CGFloat) {
        let arrowPointSize = max(12, bounds.width * 0.30)
        var configuration = NSImage.SymbolConfiguration(pointSize: arrowPointSize, weight: .heavy)
        if #available(macOS 11.0, *) {
            configuration = configuration.applying(
                NSImage.SymbolConfiguration(hierarchicalColor: NSColor(white: 1, alpha: 0.95))
            )
        }
        if scale > 1.5 {
            configuration = configuration.applying(NSImage.SymbolConfiguration(scale: .large))
        }
        
        guard let arrow = NSImage(
            systemSymbolName: "arrow.up",
            accessibilityDescription: "返回上一级"
        )?.withSymbolConfiguration(configuration) else {
            return
        }
        
        let arrowSize = arrow.size
        let arrowRect = NSRect(
            x: bounds.midX - arrowSize.width / 2,
            y: bounds.midY - arrowSize.height / 2 - bounds.height * 0.02,
            width: arrowSize.width,
            height: arrowSize.height
        )
        
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
        shadow.shadowBlurRadius = bounds.width * 0.04
        shadow.shadowOffset = NSSize(width: 0, height: -bounds.height * 0.01)
        shadow.set()
        arrow.draw(in: arrowRect)
        NSGraphicsContext.restoreGraphicsState()
    }
    
    private static func tintedFolderFallback(logicalSide: CGFloat) -> NSImage {
        let folder = NSWorkspace.shared.icon(for: .folder)
        let size = NSSize(width: logicalSide, height: logicalSide)
        let image = NSImage(size: size)
        image.lockFocus()
        let bounds = NSRect(origin: .zero, size: size)
        parentDirectoryOrange.setFill()
        bounds.fill()
        folder.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: folder.size),
            operation: .destinationIn,
            fraction: 1
        )
        drawParentDirectoryArrow(in: bounds, scale: 2)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
    
    /// 缩略图底部条用紧凑大小文案（如 `1k`、`12m`；0 仅显示 `0`，不带单位）。
    public static func compactSizeDisplay(bytes: Int64) -> String {
        guard bytes != 0 else { return "0" }
        let units: [(Int64, String)] = [
            (1_099_511_627_776, "t"),
            (1_073_741_824, "g"),
            (1_048_576, "m"),
            (1_024, "k"),
        ]
        for (threshold, suffix) in units where bytes >= threshold {
            let value = Double(bytes) / Double(threshold)
            if value >= 100 {
                return "\(Int(value.rounded()))\(suffix)"
            }
            if value >= 10 {
                return "\(Int(value.rounded()))\(suffix)"
            }
            let rounded = (value * 10).rounded() / 10
            if rounded == rounded.rounded(.towardZero) {
                return "\(Int(rounded))\(suffix)"
            }
            return String(format: "%.1f\(suffix)", rounded)
        }
        return "\(bytes)"
    }
    
    /// 在容器内保持比例放大图片：宽、高至少一边贴满容器，另一边居中，超出部分由调用方裁剪。
    public static func aspectFillFrame(imageSize: NSSize, in containerSize: NSSize) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0
        else {
            return NSRect(origin: .zero, size: containerSize)
        }
        
        let scale = max(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let displaySize = NSSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        return NSRect(
            x: (containerSize.width - displaySize.width) / 2,
            y: (containerSize.height - displaySize.height) / 2,
            width: displaySize.width,
            height: displaySize.height
        )
    }
}
