import AppKit

/// 缩略图 LRU 成本估算（内存与磁盘缓存共用）。
enum ThumbnailImageCost {
    static func estimatedBytes(of image: NSImage) -> Int {
        let size = image.size
        let scale = image.recommendedLayerContentsScale(0)
        let pixels = Int(size.width * scale) * Int(size.height * scale)
        return max(pixels * 4, 16_384)
    }
}
