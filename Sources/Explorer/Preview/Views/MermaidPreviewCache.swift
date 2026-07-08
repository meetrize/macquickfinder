import AppKit
import Foundation

/// Mermaid 预览位图 LRU 缓存（内存压力时可整表清空）。
@MainActor
final class MermaidPreviewCache {
    static let shared = MermaidPreviewCache()

    private final class Box: NSObject {
        let value: MarkdownPreviewMermaidBlock.CachedRender
        init(_ value: MarkdownPreviewMermaidBlock.CachedRender) {
            self.value = value
        }
    }

    private let storage = NSCache<NSString, Box>()

    private init() {
        storage.countLimit = 20
        storage.totalCostLimit = 32 * 1024 * 1024
    }

    subscript(key: String) -> MarkdownPreviewMermaidBlock.CachedRender? {
        get { storage.object(forKey: key as NSString)?.value }
        set {
            guard let newValue else {
                storage.removeObject(forKey: key as NSString)
                return
            }
            let cost = max(1, Int(newValue.displaySize.width * newValue.displaySize.height * 4))
            storage.setObject(Box(newValue), forKey: key as NSString, cost: cost)
        }
    }

    func clear() {
        storage.removeAllObjects()
    }
}
