import AppKit
import Foundation
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// 限制 QL 并发；回调强引用 gate，避免生成器释放后信号量未归还。
private final class QLConcurrencyGate {
    private let slots = DispatchSemaphore(value: 4)
    private let lock = NSLock()
    private var inFlight = 0
    
    func acquire() {
        slots.wait()
        lock.lock()
        inFlight += 1
        lock.unlock()
    }
    
    func release() {
        lock.lock()
        inFlight -= 1
        lock.unlock()
        slots.signal()
    }
    
    func waitUntilIdle() {
        while true {
            lock.lock()
            let count = inFlight
            lock.unlock()
            if count == 0 { return }
            Thread.sleep(forTimeInterval: 0.005)
        }
    }
}

/// 缩略图生成：Quick Look 为主，系统图标为占位与回退。
final class ThumbnailGenerator {
    enum Delivery {
        case thumbnail(NSImage)
        case icon(NSImage)
    }
    
    private let cache = ThumbnailCache()
    private let queue = DispatchQueue(label: "FileList.ThumbnailGenerator", qos: .userInitiated)
    private let qlGate = QLConcurrencyGate()
    private var activeGeneration: UInt = 0
    private let shutdownLock = NSLock()
    private var didShutdown = false
    
    private static let placeholderLock = NSLock()
    private static var genericPlaceholders: [String: NSImage] = [:]
    private let iconCacheLock = NSLock()
    private var workspaceIconCache: [String: NSImage] = [:]
    
    func cacheKey(for row: FileListRow, cellSize: CGFloat) -> ThumbnailCache.Key {
        ThumbnailCache.Key(
            row: row,
            sizeBucket: FileListThumbnailMetrics.thumbnailSizeBucket(for: cellSize)
        )
    }
    
    /// 内存 + 磁盘缓存查找，供 Cell 即时展示已缓存内容。
    func cachedImage(for row: FileListRow, cellSize: CGFloat) -> ThumbnailCache.Entry? {
        if row.isParentDirectoryEntry { return nil }
        return cache.entry(for: cacheKey(for: row, cellSize: cellSize))
    }
    
    /// 仅查内存 LRU。
    func memoryCachedImage(for row: FileListRow, cellSize: CGFloat) -> ThumbnailCache.Entry? {
        if row.isParentDirectoryEntry { return nil }
        return cache.memoryEntry(for: cacheKey(for: row, cellSize: cellSize))
    }
    
    /// 即时占位图：通用文件夹/文件图标，不访问具体路径。
    func instantPlaceholder(for row: FileListRow, cellSize: CGFloat, screenScale: CGFloat) -> NSImage {
        if row.isParentDirectoryEntry {
            return FileListThumbnailMetrics.parentDirectoryIcon(cellSize: cellSize, scale: screenScale)
        }
        return Self.genericPlaceholder(isDirectory: row.isDirectory, cellSize: cellSize)
    }
    
    deinit {
        shutdown()
    }
    
    /// 取消进行中的请求并等待 QL 槽位全部归还，避免析构时信号量仍被占用。
    func shutdown() {
        shutdownLock.lock()
        guard !didShutdown else {
            shutdownLock.unlock()
            return
        }
        didShutdown = true
        shutdownLock.unlock()
        
        activeGeneration &+= 1
        qlGate.waitUntilIdle()
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
        if row.isParentDirectoryEntry { return }
        
        let key = cacheKey(for: row, cellSize: cellSize)
        if let cached = cache.memoryEntry(for: key) {
            deliver(cached, cellSize: cellSize, completion: completion)
            return
        }
        
        let generation = activeGeneration
        queue.async { [weak self] in
            guard let self, generation == self.activeGeneration else { return }
            
            self.cache.loadEntry(for: key) { diskEntry in
                guard generation == self.activeGeneration else { return }
                
                if let diskEntry {
                    self.deliver(diskEntry, cellSize: cellSize, completion: completion)
                    return
                }
                
                self.queue.async {
                    guard generation == self.activeGeneration else { return }
                    
                    if row.isDirectory {
                        self.loadWorkspaceIcon(
                            for: row,
                            key: key,
                            cellSize: cellSize,
                            generation: generation,
                            completion: completion
                        )
                        return
                    }
                    
                    self.loadQLThumbnail(
                        for: row,
                        key: key,
                        cellSize: cellSize,
                        screenScale: screenScale,
                        generation: generation,
                        completion: completion
                    )
                }
            }
        }
    }
    
    // MARK: - Private
    
    private func deliver(
        _ entry: ThumbnailCache.Entry,
        cellSize: CGFloat,
        completion: @escaping (Delivery) -> Void
    ) {
        let image = entry.isThumbnail
            ? entry.image
            : FileListThumbnailMetrics.scaledIcon(entry.image, cellSize: cellSize)
        DispatchQueue.main.async {
            completion(entry.isThumbnail ? .thumbnail(image) : .icon(image))
        }
    }
    
    private func loadWorkspaceIcon(
        for row: FileListRow,
        key: ThumbnailCache.Key,
        cellSize: CGFloat,
        generation: UInt,
        completion: @escaping (Delivery) -> Void
    ) {
        guard generation == activeGeneration else { return }
        let icon = workspaceIcon(for: row.iconPath, cellSize: cellSize)
        cache.store(icon, isThumbnail: false, for: key)
        DispatchQueue.main.async {
            guard generation == self.activeGeneration else { return }
            completion(.icon(icon))
        }
    }
    
    private func loadQLThumbnail(
        for row: FileListRow,
        key: ThumbnailCache.Key,
        cellSize: CGFloat,
        screenScale: CGFloat,
        generation: UInt,
        completion: @escaping (Delivery) -> Void
    ) {
        let url = URL(fileURLWithPath: row.iconPath)
        let pixelSize = max(
            FileListThumbnailMetrics.minCellSize,
            CGFloat(FileListThumbnailMetrics.thumbnailSizeBucket(for: cellSize))
        ) * screenScale
        
        let gate = qlGate
        gate.acquire()
        guard generation == activeGeneration else {
            gate.release()
            return
        }
        
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: pixelSize, height: pixelSize),
            scale: screenScale,
            representationTypes: .thumbnail
        )
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            defer { gate.release() }
            guard let self else { return }
            guard generation == self.activeGeneration else { return }
            
            if let image = representation?.nsImage {
                self.cache.store(image, isThumbnail: true, for: key)
                DispatchQueue.main.async {
                    guard generation == self.activeGeneration else { return }
                    completion(.thumbnail(image))
                }
                return
            }
            
            let icon = self.workspaceIcon(for: row.iconPath, cellSize: cellSize)
            self.cache.store(icon, isThumbnail: false, for: key)
            DispatchQueue.main.async {
                guard generation == self.activeGeneration else { return }
                completion(.icon(icon))
            }
        }
    }
    
    private func workspaceIcon(for path: String, cellSize: CGFloat) -> NSImage {
        iconCacheLock.lock()
        if let cached = workspaceIconCache[path] {
            iconCacheLock.unlock()
            return FileListThumbnailMetrics.scaledIcon(cached, cellSize: cellSize)
        }
        iconCacheLock.unlock()
        
        let base = NSWorkspace.shared.icon(forFile: path)
        iconCacheLock.lock()
        workspaceIconCache[path] = base
        if workspaceIconCache.count > 300 {
            workspaceIconCache.removeAll(keepingCapacity: true)
        }
        iconCacheLock.unlock()
        return FileListThumbnailMetrics.scaledIcon(base, cellSize: cellSize)
    }
    
    private static func genericPlaceholder(isDirectory: Bool, cellSize: CGFloat) -> NSImage {
        let bucket = FileListThumbnailMetrics.thumbnailSizeBucket(for: cellSize)
        let key = "\(isDirectory)_\(bucket)"
        placeholderLock.lock()
        if let cached = genericPlaceholders[key] {
            placeholderLock.unlock()
            return cached
        }
        placeholderLock.unlock()
        
        let base = isDirectory
            ? NSWorkspace.shared.icon(for: .folder)
            : NSWorkspace.shared.icon(for: .data)
        let scaled = FileListThumbnailMetrics.scaledIcon(base, cellSize: cellSize)
        placeholderLock.lock()
        genericPlaceholders[key] = scaled
        placeholderLock.unlock()
        return scaled
    }
}
