import AppKit
import Foundation
import QuickLookThumbnailing

/// 缩略图生成：Quick Look 为主，系统图标为占位与回退。
final class ThumbnailGenerator {
    enum Delivery {
        case thumbnail(NSImage)
        case icon(NSImage)
    }
    
    private let cache = ThumbnailCache()
    private let queue = DispatchQueue(label: "FileList.ThumbnailGenerator", qos: .userInitiated)
    private var activeGeneration: UInt = 0
    
    func cacheKey(for row: FileListRow, cellSize: CGFloat) -> ThumbnailCache.Key {
        ThumbnailCache.Key(
            row: row,
            sizeBucket: FileListThumbnailMetrics.thumbnailSizeBucket(for: cellSize)
        )
    }
    
    func cachedImage(for row: FileListRow, cellSize: CGFloat) -> ThumbnailCache.Entry? {
        cache.entry(for: cacheKey(for: row, cellSize: cellSize))
    }
    
    func placeholderIcon(for row: FileListRow, cellSize: CGFloat) -> NSImage {
        let base: NSImage
        if row.isParentDirectoryEntry {
            base = NSImage(systemSymbolName: "arrow.up.circle", accessibilityDescription: nil)
                ?? NSImage(named: NSImage.folderName)
                ?? NSImage()
        } else {
            base = NSWorkspace.shared.icon(forFile: row.iconPath)
        }
        return FileListThumbnailMetrics.scaledIcon(base, cellSize: cellSize)
    }
    
    func cancelInFlightRequests() {
        activeGeneration &+= 1
    }
    
    /// 清除全部缓存（含磁盘）；目录切换不应调用此方法。
    func purgeAllCaches() {
        activeGeneration &+= 1
        cache.purgeAll()
    }
    
    func load(
        for row: FileListRow,
        cellSize: CGFloat,
        screenScale: CGFloat,
        completion: @escaping (Delivery) -> Void
    ) {
        let key = cacheKey(for: row, cellSize: cellSize)
        if let cached = cache.entry(for: key) {
            DispatchQueue.main.async {
                let image = cached.isThumbnail
                    ? cached.image
                    : FileListThumbnailMetrics.scaledIcon(cached.image, cellSize: cellSize)
                completion(cached.isThumbnail ? .thumbnail(image) : .icon(image))
            }
            return
        }
        
        if row.isParentDirectoryEntry || row.isDirectory {
            let icon = placeholderIcon(for: row, cellSize: cellSize)
            cache.store(icon, isThumbnail: false, for: key)
            DispatchQueue.main.async {
                completion(.icon(icon))
            }
            return
        }
        
        let generation = activeGeneration
        let url = URL(fileURLWithPath: row.iconPath)
        let pixelSize = max(
            FileListThumbnailMetrics.minCellSize,
            CGFloat(FileListThumbnailMetrics.thumbnailSizeBucket(for: cellSize))
        ) * screenScale
        
        queue.async { [weak self] in
            guard let self else { return }
            guard generation == self.activeGeneration else { return }
            
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: pixelSize, height: pixelSize),
                scale: screenScale,
                representationTypes: .thumbnail
            )
            
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                guard generation == self.activeGeneration else { return }
                
                if let image = representation?.nsImage {
                    self.cache.store(image, isThumbnail: true, for: key)
                    DispatchQueue.main.async {
                        guard generation == self.activeGeneration else { return }
                        completion(.thumbnail(image))
                    }
                    return
                }
                
                let icon = self.placeholderIcon(for: row, cellSize: cellSize)
                self.cache.store(icon, isThumbnail: false, for: key)
                DispatchQueue.main.async {
                    guard generation == self.activeGeneration else { return }
                    completion(.icon(icon))
                }
            }
        }
    }
}
