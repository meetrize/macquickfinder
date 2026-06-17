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
    
    /// 「..」返回上一级：按格子尺寸渲染 SF Symbol，避免小图放大发糊。
    public static func parentDirectoryIcon(cellSize: CGFloat, scale: CGFloat) -> NSImage {
        let side = iconFittingSide(in: cellSize)
        let pointSize = max(20, side * 0.72)
        var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        if #available(macOS 11.0, *) {
            configuration = configuration.applying(
                NSImage.SymbolConfiguration(hierarchicalColor: .controlAccentColor)
            )
        }
        if scale > 1.5 {
            configuration = configuration.applying(NSImage.SymbolConfiguration(scale: .large))
        }
        
        guard let symbol = NSImage(
            systemSymbolName: "arrow.up.circle.fill",
            accessibilityDescription: "返回上一级"
        )?.withSymbolConfiguration(configuration) else {
            return scaledIcon(NSImage(named: NSImage.folderName) ?? NSImage(), cellSize: cellSize)
        }
        
        let image = (symbol.copy() as? NSImage) ?? symbol
        image.size = NSSize(width: side, height: side)
        image.isTemplate = false
        return image
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
