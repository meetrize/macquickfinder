import AppKit
import CryptoKit
import Foundation

/// 缩略图磁盘缓存（PNG），减轻重复进入目录时的 QL 生成开销。
final class ThumbnailDiskCache {
    private let directoryURL: URL
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "FileList.ThumbnailDiskCache", qos: .utility)
    
    init() {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directoryURL = base.appendingPathComponent("MeoFind/ThumbnailCache", isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
    
    /// 在调用方线程同步读取磁盘缓存（经 I/O 队列），用于 Cell 配置阶段的快速命中。
    func loadSync(for key: ThumbnailCache.Key) -> ThumbnailCache.Entry? {
        ioQueue.sync {
            loadSyncUnsafe(for: key)
        }
    }
    
    /// 在后台 I/O 队列读取磁盘缓存，避免阻塞主线程。
    func load(for key: ThumbnailCache.Key, completion: @escaping (ThumbnailCache.Entry?) -> Void) {
        ioQueue.async { [weak self] in
            let entry = self?.loadSyncUnsafe(for: key)
            DispatchQueue.main.async {
                completion(entry)
            }
        }
    }
    
    private func loadSyncUnsafe(for key: ThumbnailCache.Key) -> ThumbnailCache.Entry? {
        let fileURL = fileURL(for: key)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else {
            return nil
        }
        let isThumbnail = (try? fileURL.extendedAttribute(name: "com.meofind.thumb.isThumbnail")) == Data([1])
        let cost = estimatedCost(of: image)
        return ThumbnailCache.Entry(image: image, isThumbnail: isThumbnail, cost: cost)
    }
    
    func store(_ image: NSImage, isThumbnail: Bool, for key: ThumbnailCache.Key) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        let fileURL = fileURL(for: key)
        // 同步落盘，避免用户快速离开目录时异步写入尚未完成。
        ioQueue.sync {
            try? png.write(to: fileURL, options: .atomic)
            try? fileURL.setExtendedAttribute(
                name: "com.meofind.thumb.isThumbnail",
                data: Data([isThumbnail ? 1 : 0])
            )
        }
    }
    
    func removeAll() {
        ioQueue.async { [directoryURL, fileManager] in
            guard let contents = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ) else { return }
            for url in contents {
                try? fileManager.removeItem(at: url)
            }
        }
    }
    
    private func fileURL(for key: ThumbnailCache.Key) -> URL {
        let digest = SHA256.hash(data: cacheKeyData(for: key))
        let name = digest.map { String(format: "%02x", $0) }.joined() + ".png"
        return directoryURL.appendingPathComponent(name)
    }
    
    private func cacheKeyData(for key: ThumbnailCache.Key) -> Data {
        var data = Data()
        data.append(contentsOf: key.path.utf8)
        data.append(0)
        withUnsafeBytes(of: key.modificationTimestamp.bitPattern) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt64(bitPattern: key.fileSize)) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: key.sizeBucket) { data.append(contentsOf: $0) }
        return data
    }
    
    private func estimatedCost(of image: NSImage) -> Int {
        let size = image.size
        let scale = image.recommendedLayerContentsScale(0)
        let pixels = Int(size.width * scale) * Int(size.height * scale)
        return max(pixels * 4, 16_384)
    }
}

private extension URL {
    func extendedAttribute(name: String) throws -> Data? {
        let bufferLength = getxattr(path, name, nil, 0, 0, 0)
        guard bufferLength > 0 else {
            if bufferLength == -1, errno == ENOATTR { return nil }
            return nil
        }
        var data = Data(count: bufferLength)
        let result = data.withUnsafeMutableBytes { buffer in
            getxattr(path, name, buffer.baseAddress, bufferLength, 0, 0)
        }
        guard result >= 0 else { return nil }
        return data
    }
    
    func setExtendedAttribute(name: String, data: Data) throws {
        try data.withUnsafeBytes { buffer in
            guard setxattr(path, name, buffer.baseAddress, buffer.count, 0, 0) == 0 else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
        }
    }
}
