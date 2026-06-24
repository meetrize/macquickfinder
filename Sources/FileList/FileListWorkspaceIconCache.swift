import AppKit

/// 列表与缩略图共用的 `NSWorkspace` 图标缓存，避免主线程重复读取文件元数据。
public enum FileListWorkspaceIconCache {
    private static var cache: [String: NSImage] = [:]
    private static var accessOrder: [String] = []
    private static let lock = NSLock()
    private static let maxEntries = 300

    public static func icon(forPath path: String) -> NSImage {
        lock.lock()
        if let cached = cache[path] {
            touchLocked(path)
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image = NSWorkspace.shared.icon(forFile: path)
        lock.lock()
        cache[path] = image
        accessOrder.append(path)
        evictIfNeededLocked()
        lock.unlock()
        return image
    }

    private static func touchLocked(_ path: String) {
        accessOrder.removeAll { $0 == path }
        accessOrder.append(path)
    }

    private static func evictIfNeededLocked() {
        while cache.count > maxEntries, let oldest = accessOrder.first {
            accessOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }
}
